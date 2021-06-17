void printf_wrap(const char* str){
  volatile char* const tx_en = (char *)0x54000008;
  volatile char* const tx_addr = (char *)0x54000000;
  *tx_en = 0x1;
  while(*str){
    *tx_addr = *str;
    str++;
  }
}

int main(){
  printf_wrap("Hello World\n");
  return 0;
}
