#include <ets_sys.h>
#include <osapi.h>
#include <gpio.h>
#include <os_type.h>
#include <user_config.h>
#include <mem.h>
#include <upgrade.h>

#include <driver/key.h>

volatile os_timer_t blink_timer;

void blink_fun(void *arg)
{	//Do blinky stuff
    if (GPIO_REG_READ(GPIO_OUT_ADDRESS) & BIT2)
    	gpio_output_set(0, BIT2, BIT2, 0);
    else
        gpio_output_set(BIT2, 0, BIT2, 0);

    os_printf("APP1 code! Now running %s\n", (system_upgrade_userbin_check() == UPGRADE_FW_BIN1)?"FW_BIN1":"FW_BIN2");
}

void ICACHE_FLASH_ATTR button_down_cb(void)
{
	os_printf("button down - upgrade flag set\n");

	system_upgrade_flag_set(UPGRADE_FLAG_FINISH);
}

void ICACHE_FLASH_ATTR button_down_5s_cb(void)
{
	os_printf("button long press - reboot\n");
	system_upgrade_reboot();
}

static void ICACHE_FLASH_ATTR init_button_input(void)
{
	static struct keys_param keys;
	static struct single_key_param *cfg_key;

	cfg_key = key_init_single(0, PERIPHS_IO_MUX_GPIO0_U, FUNC_GPIO0, button_down_5s_cb, button_down_cb);
	keys.key_num = 1;
	keys.single_key = &cfg_key;
	key_init(&keys);
}


void ICACHE_FLASH_ATTR user_init()
{
	uart_div_modify(0, UART_CLK_FREQ / 115200);
    gpio_init();

    PIN_FUNC_SELECT(PERIPHS_IO_MUX_GPIO2_U, FUNC_GPIO2);

    os_timer_disarm(&blink_timer);
    os_timer_setfn(&blink_timer, (os_timer_func_t *)blink_fun, NULL);
    os_timer_arm(&blink_timer, 1000, 1);
    
    init_button_input();
    os_printf("Hello. now running %s\n", (system_upgrade_userbin_check() == UPGRADE_FW_BIN1)?"FW_BIN1":"BIN2");
}
