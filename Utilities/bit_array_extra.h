//
//  bit_array_extra.h
//
//	Extra methods for BitArray library by Isaac Turner <turner.isaac@gmail.com>
//
//  Created by Sergey Filippov on 7/9/13.
//  Copyright (c) 2013 Lapka. All rights reserved.
//

#include <stdio.h>
#include "bit_array.h"


uint8_t bit_array_get_reversed_word8(BIT_ARRAY *array, int start);
uint8_t bit_array_get_reversed_word16(BIT_ARRAY *array, int start);