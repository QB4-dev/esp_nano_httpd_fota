# esp_nano_httpd FOTA example

To compile yourself:

git clone https://github.com/QB4-dev/esp_nano_httpd_ota --recursive

cd esp_nano_httpd_ota/

make

make flash

In this example you can test FOTA upgrade feature. It is tested on ESP-12 board. To use it on ESP-01 please change in Makefile
```Makefile
#SPI flash size, in K
ESP_SPI_FLASH_SIZE_K=4096
```
to 
```Makefile
#SPI flash size, in K
ESP_SPI_FLASH_SIZE_K=1024
```
In case of errors during boot execute
`make flashinit`
This will fix flash rf_cal section

<img src="https://gfycat.com/UnsungObedientAmericankestrel" width="1024" height="768" />

You can also check file upload feature. Just upload text file and see it's content in iframe
