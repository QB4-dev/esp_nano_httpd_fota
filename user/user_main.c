#include <ets_sys.h>
#include <osapi.h>
#include <gpio.h>
#include <mem.h>
#include <os_type.h>
#include <user_config.h>
#include <upgrade.h>

#include "esp_nano_httpd.h"
#include "util/wifi_util.h"
#include "util/file_upload.h"
#include "util/firmware_upgrade.h"

#include "../html/include/index.h"

static os_timer_t blink_timer;

void blink_fun(void *arg)
{	//Do blinky stuff
    if (GPIO_REG_READ(GPIO_OUT_ADDRESS) & BIT2)
    	gpio_output_set(0, BIT2, BIT2, 0);
    else
        gpio_output_set(BIT2, 0, BIT2, 0);
}

file_info_t flash_txt_file = {
	.accept_file_ext = ".txt",
	.accept_cont_type = "text",
	.base_sec = 0x250,
	.max_f_size = 4*SPI_FLASH_SEC_SIZE
};

void ICACHE_FLASH_ATTR flash_read_callback(struct espconn *conn, void *arg, uint32_t len)
{
	http_request_t *req = conn->reverse;
	file_info_t *f_info = (file_info_t*)arg;
	char *html;
	char *flash_buff;
	char *flash_data;
	uint32_t data_len=0;
	uint32_t i;
	const char header[]= "<!DOCTYPE html><html lang=\"en\">"
						"<head><title>flash content</title></head>"
						"<body style=\"font-family:Arial;\">\r\n";
	const char end[] = "</body></html>";


	//handle only GET request with query
	if(req == NULL || req->type == TYPE_POST) return resp_http_error(conn);

	flash_buff = (char *)os_malloc(f_info->max_f_size);
	if(flash_buff == NULL) return resp_http_error(conn);

	spi_flash_read(f_info->base_sec*SPI_FLASH_SEC_SIZE, (uint32*)flash_buff, f_info->max_f_size);
	for(i=0 ; i<f_info->max_f_size; i++){
		data_len++;
		if(flash_buff[i]==0 || flash_buff[i]==0xff)break;
	}
	flash_data = (char *)os_malloc(data_len);
	if(flash_data == NULL) return resp_http_error(conn);

	os_memcpy(flash_data, flash_buff, data_len);
	os_free(flash_buff);

	html = (char *)os_malloc(data_len+256);
	if(html == NULL) return resp_http_error(conn);

	os_strcpy(html, header);
	os_memcpy(html+strlen(html), flash_data, data_len);
	os_strcpy(html+strlen(header)+data_len-1,end);

	os_free(flash_data);

	send_html(conn,(void*)html,strlen(html));
	os_free(html);
}

// URL config table
const http_callback_t url_cfg[] = {
	{"/",		send_html, 					index_html, 	sizeof(index_html)},
	{"/wifi",	wifi_callback, 				NULL, 			0 },
	{"/read",	flash_read_callback,		&flash_txt_file,0 },
	{"/upgrade",firmware_upgrade_callback, 	NULL,			0 },
	{"/upload",	file_upload_callback, 		&flash_txt_file,0 },
	{0,0,0,0}
};

void ICACHE_FLASH_ATTR user_init()
{
    uart_div_modify(0, UART_CLK_FREQ / 115200);
    gpio_init();

    PIN_FUNC_SELECT(PERIPHS_IO_MUX_GPIO2_U, FUNC_GPIO2);

    wifi_status_led_uninstall();
    os_timer_disarm(&blink_timer);
    os_timer_setfn(&blink_timer, (os_timer_func_t *)blink_fun, NULL);
    os_timer_arm(&blink_timer, 1000, 1);
    
    esp_nano_httpd_register_content(url_cfg);
    esp_nano_httpd_init_AP(STATIONAP_MODE, "ESP_FOTA");
}
