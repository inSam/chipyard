#include <stdio.h>
#include "rocc.h"

static inline unsigned long rng_get()
{
  unsigned long value;
  ROCC_INSTRUCTION_D(1, value, 0);
  return value;
}

int main(){

  unsigned long rng_val;
  for (int i = 0; i < 10; i++){
    rng_val = 5;
    printf("rng: %lu\n", rng_val);
  }

  return 0;
}
