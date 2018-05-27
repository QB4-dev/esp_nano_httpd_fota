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
}

file_info_t flash_wav_file = {
	.accept_cont_type = "text",
	.base_sec = 0x250,
	.max_f_size = 64*SPI_FLASH_SEC_SIZE
};

// URL config table
const http_callback_t url_cfg[] = {
	{"/", send_html, index_html, sizeof(index_html)},
	{"/wifi", wifi_callback, NULL, 0},
	{"/upgrade", firmware_upgrade_callback, NULL, 0 },
	{"/upload", file_upload_callback, &flash_wav_file, 0 },
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
