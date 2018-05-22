#include <ets_sys.h>
#include <osapi.h>
#include <gpio.h>
#include <os_type.h>
#include <user_config.h>
#include <upgrade.h>

#include "../esp_nano_httpd/esp_nano_httpd.h"
#include "../esp_nano_httpd/util/nano_httpd_wifi_util.h"
#include "../esp_nano_httpd/util/nano_httpd_file_upload.h"

#include "../html/include/index.h"

static volatile os_timer_t blink_timer;

void blink_fun(void *arg)
{	//Do blinky stuff
    if (GPIO_REG_READ(GPIO_OUT_ADDRESS) & BIT2)
    	gpio_output_set(0, BIT2, BIT2, 0);
    else
        gpio_output_set(BIT2, 0, BIT2, 0);

    //os_printf("FOTA fw upgrade %s! Now running %s\n", __TIME__, (system_upgrade_userbin_check() == UPGRADE_FW_BIN1)?"FW_BIN1":"FW_BIN2");
}


void ICACHE_FLASH_ATTR led_demo_callback(struct espconn *conn, void *arg, uint32_t len)
{
	uint32_t freq;
	char *param;
	http_request_t *req = conn->reverse;

	//handle only GET request with query
	if(req == NULL || req->type != TYPE_GET || req->query == NULL) return resp_http_error(conn);

	param=strtok((char*)req->query,"&");
	if( os_memcmp(param,"led_freq=",9) == 0 ){  //led frequency request
		freq = atoi(strchr(param,'=')+1);
		if(freq != 0){
			os_timer_disarm(&blink_timer);
			os_timer_setfn(&blink_timer, (os_timer_func_t *)blink_fun, NULL);
			os_timer_arm(&blink_timer, 1000/freq, 1); //set new frequency
			os_printf("new LED frequency set. f=%dHz\n", freq);
		}
	}
	resp_http_ok(conn);
}

void ICACHE_FLASH_ATTR reboot_cb(struct espconn *conn, void *arg, uint32_t len)
{
    http_request_t *req = conn->reverse;
    file_info_t *wav_file = arg;

    if(req == NULL) return resp_http_error(conn);
    if(req->type == TYPE_GET){
		os_printf("OTA reboot\n");

		resp_http_ok(conn);
		os_delay_us(500000);
		system_upgrade_flag_set(UPGRADE_FLAG_FINISH);
		system_upgrade_reboot();
    }
    //resp_http_ok(conn);
}

file_info_t flash_wav_file = {
	.accept_cont_type = "application/octet-stream",
	.base_sec = 0x101,
	.max_f_size = 128*SPI_FLASH_SEC_SIZE
};

// URL config table
const http_callback_t url_cfg[] = {
	{"/", send_html, index_html, sizeof(index_html)},
	{"/led",  led_demo_callback, NULL, 0},
	{"/wifi", wifi_callback, NULL, 0},
	{"/upload", firmware_upgrade_callback, NULL, 0 },
	{"/reboot", reboot_cb, NULL, 0 },
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
