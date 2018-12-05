CC=gcc -std=c99 -I ../native/common

audiana: audiana.c wave.o
	$(CC) -o $@ $^

wave.o: wave.c
	$(CC) -c $^

#
# Clean
#
clean:
	rm -f audiana *.o *~
