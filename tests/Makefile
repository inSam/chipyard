GCC=riscv64-unknown-elf-gcc
OBJDUMP=riscv64-unknown-elf-objdump
CFLAGS= -std=gnu99 -O2 -fno-common -fno-builtin-printf -Wall
LDFLAGS= -static -T htif.ld -nostdlib -nostartfiles -lgcc

PROGRAMS = pwm blkdev accum charcount nic-loopback big-blkdev pingd \
           streaming-passthrough streaming-fir nvdla spiflashread spiflashwrite \
	   printf rng aes rng_noa empty aes_empty aes_bulk aes256 hello_world \
	   rng_uart aes_uart

spiflash.img: spiflash.py
	python3 $<

.DEFAULT_GOAL := default

.PHONY: default
default: $(addsuffix .riscv,$(PROGRAMS)) spiflash.img

.PHONY: dumps
dumps: $(addsuffix .dump,$(PROGRAMS))

%.o: %.S
	$(GCC) $(CFLAGS) -D__ASSEMBLY__=1 -c $< -o $@

%.o: %.c mmio.h spiflash.h
	$(GCC) $(CFLAGS) -c $< -o $@

%.riscv: %.o crt.o syscalls.o
	$(GCC) $(LDFLAGS) $^ -o $@

%.dump: %.riscv
	$(OBJDUMP) -D $< > $@


.PHONY: clean
clean:
	rm -f *.riscv *.o *.dump
