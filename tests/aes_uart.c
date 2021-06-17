#include <stdlib.h>
#include <stdio.h>
#include "rocc.h"

void printf_wrap(const char* str){
  volatile char* const tx_en = (char *)0x54000008;
  volatile char* const tx_addr = (char *)0x54000000;
  *tx_en = 0x1;
  while(*str){
    *tx_addr = *str;
    str++;
  }
}

static inline void aes_ldkey(void *key_addr)
{
        asm volatile ("fence");
        unsigned long value;
	ROCC_INSTRUCTION_DS(0, value, (uintptr_t)key_addr, 0)
}

static inline void aes_encrypt(void *read_addr, void *write_addr)
{
        asm volatile ("fence");
        unsigned long value;
	ROCC_INSTRUCTION_DSS(0, value, (uintptr_t)read_addr, (uintptr_t)write_addr, 1)
}

static inline void aes_decrypt(void *read_addr, void *write_addr)
{
        asm volatile ("fence");
        unsigned long value;
	ROCC_INSTRUCTION_DSS(0, value, (uintptr_t)read_addr, (uintptr_t)write_addr, 2)
}

//0xfeefaf8
int main(void)
{
    uint8_t i;
    uint8_t key [16] __attribute__ ((aligned (8)));
    uint8_t *key_temp = key;
    uint8_t data [16] __attribute__ ((aligned (8)));
    uint8_t *data_temp = data;
    uint8_t out [16] __attribute__ ((aligned (8)));
    uint8_t decrypted [16] __attribute__ ((aligned (8)));

    char str[64];

    /* put a test vector */
    printf_wrap("key: ");
    /* for (i = 0; i < 8; i++) { */
    /*     *key_temp = 0x12; */
    /*     printf("%02x ", *key_temp); */
    /*     key_temp++; */
    /* } */
    /* for (i = 8; i < 16; i++) { */
    /*     *key_temp = 0x34; */
    /*     printf("%02x ", *key_temp); */
    /*     key_temp++; */
    /* } */
    /* for (i = 16; i < 24; i++) { */
    /* 	*key_temp = 0x56; */
    /* 	printf("%02x ", *key_temp); */
    /* 	key_temp++; */
    /* } */
    /* for (i = 24; i < 32; i++) { */
    /*     *key_temp = 0x78; */
    /*     printf("%02x ", *key_temp); */
    /*     key_temp++; */
    /* } */
    printf_wrap("\n");

    aes_ldkey(key);


    printf_wrap("data: ");
    /* for (i = 0; i < 4; i++) { */
    /*     *data_temp = 0x12; */
    /*     printf("%02x ", *data_temp); */
    /*     data_temp++; */
    /* } */
    /* for (i = 4; i < 8; i++) { */
    /*     *data_temp = 0x34; */
    /*     printf("%02x ", *data_temp); */
    /*     data_temp++; */
    /* } */
    /* for (i = 8; i < 12; i++) { */
    /*     *data_temp = 0xab; */
    /*     printf("%02x ", *data_temp); */
    /*     data_temp++; */
    /* } */
    /* for (i = 12; i < 16; i++) { */
    /*     *data_temp = 0xcd; */
    /*     printf("%02x ", *data_temp); */
    /*     data_temp++; */
    /* } */
    printf_wrap("\n");
    aes_encrypt(data, out);
    printf_wrap("encrypted data: ");
    /* for (i = 0; i < 16; i++) { */
    /* 	printf("%02x ", out[i]); */
    /* } */
    printf_wrap("\n");

    aes_decrypt(out, decrypted);
    printf_wrap("decrypted data: ");
    /* for (i = 0; i < 16; i++) { */
    /*     printf("%02x ", decrypted[i]); */
    /* } */
    printf_wrap("\n");

    return 0;
}
