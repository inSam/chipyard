#include <stdlib.h>
#include <stdio.h>
#include "rocc.h"

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
unsigned long read_cycles(void)
{
    unsigned long cycles;
    asm volatile ("rdcycle %0" : "=r" (cycles));
    return cycles;
}

//0xfeefaf8
int main(void)
{
    for(char test = 0; test <100; test++){
        unsigned long start =read_cycles();
        uint8_t i;
        uint8_t key [256] __attribute__ ((aligned (8)));
        uint8_t *key_temp = key;
        uint8_t data [256] __attribute__ ((aligned (8)));
        uint8_t *data_temp = data;
        uint8_t out [256] __attribute__ ((aligned (8)));
        uint8_t decrypted [256] __attribute__ ((aligned (8)));

        /* put a test vector */
        // printf("key: ");
        for (i = 0; i < 8; i++) {
            *key_temp = 0x12;
            // printf("%02x ", *key_temp);
            key_temp++;
        }
        for (i = 8; i < 16; i++) {
            *key_temp = 0x34;
            // printf("%02x ", *key_temp);
            key_temp++;
        }
        for (i = 16; i < 24; i++) {
        	*key_temp = 0x56;
        	// printf("%02x ", *key_temp);
        	key_temp++;
        }
        for (i = 24; i < 32; i++) {
            *key_temp = 0x78;
            // printf("%02x ", *key_temp);
            key_temp++;
        }
        // printf("\n");

        aes_ldkey(key);


        // printf("data: ");
        for (i = 0; i < 4; i++) {
            // *data_temp = 0x12;
            *data_temp = 0x01 + test % 0xff;
            // printf("%02x ", *data_temp);
            data_temp++;
        }
        for (i = 4; i < 8; i++) {
            *data_temp = 0x01 + test % 0xff;
            // printf("%02x ", *data_temp);
            data_temp++;
        }
        for (i = 8; i < 12; i++) {
            *data_temp = 0x01 + test % 0xff;
            // printf("%02x ", *data_temp);
            data_temp++;
        }
        for (i = 12; i < 16; i++) {
            *data_temp = 0x01 + test % 0xff;
            // printf("%02x ", *data_temp);
            data_temp++;
        }
        // printf("\n");
        aes_encrypt(data, out);
        // printf("encrypted data: ");
        // for (i = 0; i < 16; i++) {
        	// printf("%02x ", out[i]);
        // }
        // printf("\n");

        aes_decrypt(out, decrypted);

        unsigned long end =read_cycles();
        unsigned long total = end - start;
        printf("time: %lu \n", total);

        // printf("decrypted data: ");
        // for (i = 0; i < 16; i++) {
        //     printf("%02x ", decrypted[i]);
        // }
        // printf("\n");
        // clock_t end = clock();
        // double cpu_time_used = ((double) (end - start)) / CLOCKS_PER_SEC;
        // printf("time: %f \n", cpu_time_used);
    }

	return 0;
}
