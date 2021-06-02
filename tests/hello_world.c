void printf_wrap(const char* str){
  char* const tx_addr = (char *)0x54000000;
  while(*str){
    *tx_addr = *str;
    str++;
  }
}

int main(){
  printf_wrap("Hello World\n");
  return 0;
}
