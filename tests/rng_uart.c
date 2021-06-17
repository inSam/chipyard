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

static inline unsigned long rng_get()
{
  unsigned long value;
  ROCC_INSTRUCTION_D(1, value, 0);
  return value;
}

int main(){

  unsigned long rng_val;
  char str[1024];
  for (int i = 0; i < 3; i++){
    rng_val = rng_get();
    sprintf(str, "%lu", rng_val);
    printf_wrap(str);
    printf_wrap("\n");
  }

  return 0;
}
