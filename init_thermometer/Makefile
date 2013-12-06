BIN=init_thermometer
SRC=init_thermometer.c
CC=gcc
FLAGS=-Wall -Wextra -pedantic -std=gnu99 -O0 -g
LIBS=

$(BIN): $(SRC)
	$(CC) $(FLAGS) $(LIBS) -o $(BIN) $(SRC)

clean:
	rm $(BIN)
