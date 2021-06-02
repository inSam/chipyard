#include <stdio.h>
#include <stdlib.h>


unsigned long read_cycles(void)
{
    unsigned long cycles;
    asm volatile ("rdcycle %0" : "=r" (cycles));
    return cycles;
}

int main(){

  unsigned long rng_val;
  for (int i = 0; i < 10; i++){
    unsigned long start =read_cycles();
    rng_val = rand();
    unsigned long end =read_cycles();
    unsigned long total = end - start;
    printf("time: %lu \n", total);
  }

  return 0;
}
