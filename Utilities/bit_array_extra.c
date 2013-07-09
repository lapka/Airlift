//
//  bit_array_extra.c
//
//  Created by Sergey Filippov on 7/9/13.
//  Copyright (c) 2013 Lapka. All rights reserved.
//

#include <stdio.h>
#include "bit_array_extra.h"


uint8_t bit_array_get_reversed_word8(BIT_ARRAY *array, int start) {

	uint8_t word =
	bit_array_get(array, start+0) << 7 |
	bit_array_get(array, start+1) << 6 |
	bit_array_get(array, start+2) << 5 |
	bit_array_get(array, start+3) << 4 |
	bit_array_get(array, start+4) << 3 |
	bit_array_get(array, start+5) << 2 |
	bit_array_get(array, start+6) << 1 |
	bit_array_get(array, start+7);
	
	return word;
}

uint8_t bit_array_get_reversed_word16(BIT_ARRAY *array, int start) {
	
	uint16_t word =
	bit_array_get(array, start+0)  << 15 |
	bit_array_get(array, start+1)  << 14 |
	bit_array_get(array, start+2)  << 13 |
	bit_array_get(array, start+3)  << 12 |
	bit_array_get(array, start+4)  << 11 |
	bit_array_get(array, start+5)  << 10 |
	bit_array_get(array, start+6)  << 9  |
	bit_array_get(array, start+7)  << 8  |
	bit_array_get(array, start+8)  << 7  |
	bit_array_get(array, start+9)  << 6  |
	bit_array_get(array, start+10) << 5  |
	bit_array_get(array, start+11) << 4  |
	bit_array_get(array, start+12) << 3  |
	bit_array_get(array, start+13) << 2  |
	bit_array_get(array, start+14) << 1  |
	bit_array_get(array, start+15);
	
	return word;
}