// See LICENSE for license details.

#include <stdint.h>
#include <string.h>
#include <stdarg.h>
#include <stdio.h>

#include "encoding.h"
#include "mmio.h"

#define static_assert(cond) switch(0) { case 0: case !!(long)(cond): ; }

#undef strcmp

// To exit, send one byte to address SYS_EXIT and just loop.
// If we receive another interrupt, we reboot.
 void __attribute__((noreturn)) exit(int code)
{
  /* char buf[128 / 8] = {0}; */
  /* *(int *)buf = code; */


  /* // c2c_1_write((uint64_t)buf, SYS_EXIT, 1); // change to c2c_1_write */
  /* c2c_write((uint64_t)buf, SYS_EXIT, 1); */

  /* __asm__ volatile ( */
  /* 		    "c2c_exit_loop:" */
  /* 		    "wfi\n" */
  /* 		    "j c2c_exit_loop\n" */
  /* 		    "nop\n" */
  /* 		    "nop\n" */
  /* 		    "j _start\n" */
  /* 		    ); */

  /* __builtin_unreachable(); */
}
// Enable interrupts by setting the correct CPU registers.
/* static void enable_interrupts() { */
/*   // Clear exisiting machine interrupts */
/*   reg_write8(MSIP_REG, 0); */

/*   // Clear existing supervisor interrupt */
/*   clear_csr(mip, MIP_SEIP); */

/*   // Enable supervisor + machine interrupts */
/*   set_csr(mstatus, MSTATUS_SIE | MSTATUS_MIE); */
/*   set_csr(mie, MIP_SEIP | MIP_MEIP); */

/*   // Configure the interrupt on the PLIC */
/*   reg_write8(PLIC_REG+0x2000, 0xF); // enable */
/*   reg_write8(PLIC_REG+0x4, 0xF); // priority */
/*   reg_write8(PLIC_REG+0x200000, 0); // threshold */
/* } */

uintptr_t __attribute__((weak)) handle_trap(uintptr_t cause, uintptr_t epc, uintptr_t regs[32]) {
  // printf("Interrupt Handler Called.\n");

  /* uint64_t interrupt = cause; */
  /* if (interrupt >> 63 == 1) { */
  /*   uint64_t id = ( interrupt << 1 )  >> 1; // clear top bit */

  /*   if (id == 3) { */
  /*     // Clear interrupt */
  /*     reg_write8(MSIP_REG, 0); */

  /*     printf("Software Interrupt Received.\n"); */

  /*     // Resume to next instruction after jump */
  /*     return epc + 4; */
  /*   } else if (id == 11) { */
  /*     reg_write8(ACC_ACK, 1); */
  /*     printf("Runtime: %lu cycles\n", reg_read64(ACC_CYCLE_COUNT)); */
  /*     exit(0); */

  /*     // Claim the interrupt */
  /*     const uint64_t claim_number = reg_read32(PLIC_REG + 0x200000+4); */

  /*     // Mark it as claimed */
  /*     reg_write32(PLIC_REG + 0x200000+4, claim_number); */

  /*     // Resume to next instruction after jump */
  /*     return epc + 2; */
  /*   } else { */
  /*     printf("Unknown Interrupt: %lu\n", id); */
  /*   } */
  /* } */
  /* else { */
  /*   printf("Exception! Cause: %lu PC: %lu\n", cause, epc); */
  /*   uintptr_t faulting_address = read_csr(mtval); */
  /*   printf("Faulting Address: %lu\n", faulting_address); */
  /* } */

  // exit(EXIT_INT_ERROR);
}

void abort() {
  // exit(EXIT_ABRT);
}

void printstr(const char *s) {
  //c2c_1_write((uint64_t)s, SYS_WRITE, ((strlen(s) + 1)*8 + 127) / 128); // change to c2c_1_write
  // c2c_write((uint64_t)s, SYS_WRITE, ((strlen(s) + 1)*8 + 127) / 128);
}

void __attribute__((weak)) thread_entry(int cid, int nc) {
  // multi-threaded programs override this function.
  // for the case of single-threaded programs, only let core 0 proceed.
  while (cid != 0);
}

int __attribute__((weak)) main(int argc, char** argv) {
  // single-threaded programs override this function.
  printstr("Implement main(), foo!\n");
  return -1;
}

static void init_tls() {
  register void* thread_pointer asm("tp");
  extern char _tls_data;
  extern __thread char _tdata_begin, _tdata_end, _tbss_end;
  size_t tdata_size = &_tdata_end - &_tdata_begin;
  memcpy(thread_pointer, &_tls_data, tdata_size);
  size_t tbss_size = &_tbss_end - &_tdata_end;
  memset(thread_pointer + tdata_size, 0, tbss_size);
}

void _init(int cid, int nc) {
  // init_tls();
  thread_entry(cid, nc);

  // enable_interrupts();

  // only single-threaded programs should ever get here.
  int ret = main(0, 0);

  exit(ret);
}

/* #undef putchar */
/* int putchar(int ch) { */
/*   static char buf[128] = {0}; */
/*   static int buflen = 0; */

/*   buf[buflen++] = ch; */

/*   if (ch == '\n' || buflen == sizeof(buf) - 2) { */
/*     buf[buflen] = '\0'; */
/*     printstr(buf); */

/*     for (int i = 0; i < buflen; i++) buf[i] = 0; */
/*     buflen = 0; */
/*   } */

/*   return 0; */
/* } */

void printhex(uint64_t x) {
  char str[17];
  int i;
  for (i = 0; i < 16; i++)
    {
      str[15-i] = (x & 0xF) + ((x & 0xF) < 10 ? '0' : 'a'-10);
      x >>= 4;
    }
  str[16] = 0;

  printstr(str);
}

static inline void printnum(void (*putch)(int, void**), void **putdat,
			    unsigned long long num, unsigned base, int width, int padc)
{
  unsigned digs[sizeof(num)*8];
  int pos = 0;

  while (1)
    {
      digs[pos++] = num % base;
      if (num < base)
	break;
      num /= base;
    }

  while (width-- > pos)
    putch(padc, putdat);

  while (pos-- > 0)
    putch(digs[pos] + (digs[pos] >= 10 ? 'a' - 10 : '0'), putdat);
}

static unsigned long long getuint(va_list *ap, int lflag) {
  if (lflag >= 2)
    return va_arg(*ap, unsigned long long);
  else if (lflag)
    return va_arg(*ap, unsigned long);
  else
    return va_arg(*ap, unsigned int);
}

static long long getint(va_list *ap, int lflag) {
  if (lflag >= 2)
    return va_arg(*ap, long long);
  else if (lflag)
    return va_arg(*ap, long);
  else
    return va_arg(*ap, int);
}

static void vprintfmt(void (*putch)(int, void**), void **putdat, const char *fmt, va_list ap) {
  register const char* p;
  const char* last_fmt;
  register int ch, err;
  unsigned long long num;
  int base, lflag, width, precision, altflag;
  char padc;

  while (1) {
    while ((ch = *(unsigned char *) fmt) != '%') {
      if (ch == '\0')
	return;
      fmt++;
      putch(ch, putdat);
    }
    fmt++;

    // Process a %-escape sequence
    last_fmt = fmt;
    padc = ' ';
    width = -1;
    precision = -1;
    lflag = 0;
    altflag = 0;
  reswitch:
    switch (ch = *(unsigned char *) fmt++) {

      // flag to pad on the right
    case '-':
      padc = '-';
      goto reswitch;

      // flag to pad with 0's instead of spaces
    case '0':
      padc = '0';
      goto reswitch;

      // width field
    case '1':
    case '2':
    case '3':
    case '4':
    case '5':
    case '6':
    case '7':
    case '8':
    case '9':
      for (precision = 0; ; ++fmt) {
	precision = precision * 10 + ch - '0';
	ch = *fmt;
	if (ch < '0' || ch > '9')
	  break;
      }
      goto process_precision;

    case '*':
      precision = va_arg(ap, int);
      goto process_precision;

    case '.':
      if (width < 0)
	width = 0;
      goto reswitch;

    case '#':
      altflag = 1;
      goto reswitch;

    process_precision:
      if (width < 0)
	width = precision, precision = -1;
      goto reswitch;

      // long flag (doubled for long long)
    case 'l':
      lflag++;
      goto reswitch;

      // character
    case 'c':
      putch(va_arg(ap, int), putdat);
      break;

      // string
    case 's':
      if ((p = va_arg(ap, char *)) == NULL)
	p = "(null)";
      if (width > 0 && padc != '-')
	for (width -= strnlen(p, precision); width > 0; width--)
	  putch(padc, putdat);
      for (; (ch = *p) != '\0' && (precision < 0 || --precision >= 0); width--) {
	putch(ch, putdat);
	p++;
      }
      for (; width > 0; width--)
	putch(' ', putdat);
      break;

      // (signed) decimal
    case 'd':
      num = getint(&ap, lflag);
      if ((long long) num < 0) {
	putch('-', putdat);
	num = -(long long) num;
      }
      base = 10;
      goto signed_number;

      // unsigned decimal
    case 'u':
      base = 10;
      goto unsigned_number;

      // (unsigned) octal
    case 'o':
      // should do something with padding so it's always 3 octits
      base = 8;
      goto unsigned_number;

      // pointer
    case 'p':
      static_assert(sizeof(long) == sizeof(void*));
      lflag = 1;
      putch('0', putdat);
      putch('x', putdat);
      /* fall through to 'x' */

      // (unsigned) hexadecimal
    case 'x':
      base = 16;
    unsigned_number:
      num = getuint(&ap, lflag);
    signed_number:
      printnum(putch, putdat, num, base, width, padc);
      break;

      // escaped '%' character
    case '%':
      putch(ch, putdat);
      break;

      // unrecognized escape sequence - just print it literally
    default:
      putch('%', putdat);
      fmt = last_fmt;
      break;
    }
  }
}

/* int printf(const char* fmt, ...) { */
/*   va_list ap; */
/*   va_start(ap, fmt); */

/*   vprintfmt((void*)putchar, 0, fmt, ap); */

/*   va_end(ap); */
/*   return 0; // incorrect return value, but who cares, anyway? */
/* } */

int sprintf(char* str, const char* fmt, ...) {
  va_list ap;
  char* str0 = str;
  va_start(ap, fmt);

  void sprintf_putch(int ch, void** data)
  {
    char** pstr = (char**)data;
    **pstr = ch;
    (*pstr)++;
  }

  vprintfmt(sprintf_putch, (void**)&str, fmt, ap);
  *str = 0;

  va_end(ap);
  return str - str0;
}

void* memcpy(void* dest, const void* src, size_t len) {
  if ((((uintptr_t)dest | (uintptr_t)src | len) & (sizeof(uintptr_t)-1)) == 0) {
    const uintptr_t* s = src;
    uintptr_t *d = dest;
    while (d < (uintptr_t*)(dest + len))
      *d++ = *s++;
  } else {
    const char* s = src;
    char *d = dest;
    while (d < (char*)(dest + len))
      *d++ = *s++;
  }
  return dest;
}

void* memset(void* dest, int byte, size_t len) {
  if ((((uintptr_t)dest | len) & (sizeof(uintptr_t)-1)) == 0) {
    uintptr_t word = byte & 0xFF;
    word |= word << 8;
    word |= word << 16;
    word |= word << 16 << 16;

    uintptr_t *d = dest;
    while (d < (uintptr_t*)(dest + len))
      *d++ = word;
  } else {
    char *d = dest;
    while (d < (char*)(dest + len))
      *d++ = byte;
  }
  return dest;
}

size_t strlen(const char *s) {
  const char *p = s;
  while (*p)
    p++;
  return p - s;
}

size_t strnlen(const char *s, size_t n) {
  const char *p = s;
  while (n-- && *p)
    p++;
  return p - s;
}

int strcmp(const char* s1, const char* s2) {
  unsigned char c1, c2;

  do {
    c1 = *s1++;
    c2 = *s2++;
  } while (c1 != 0 && c1 == c2);

  return c1 - c2;
}

char* strcpy(char* dest, const char* src) {
  char* d = dest;
  while ((*d++ = *src++))
    ;
  return dest;
}

long atol(const char* str) {
  long res = 0;
  int sign = 0;

  while (*str == ' ')
    str++;

  if (*str == '-' || *str == '+') {
    sign = *str == '-';
    str++;
  }

  while (*str) {
    res *= 10;
    res += *str++ - '0';
  }

  return sign ? -res : res;
}
