/*** asmMult.s   ***/
/* Tell the assembler to allow both 16b and 32b extended Thumb instructions */
.syntax unified

/* Tell the assembler that what follows is in data memory    */
.data
.align
 
/* define and initialize global variables that C can access */
/* create a string */
.global nameStr
.type nameStr,%gnu_unique_object
    
/*** STUDENTS: Change the next line to your name!  **/
nameStr: .asciz "Vivian Overbey"  

.align   /* realign so that next mem allocations are on word boundaries */
 
/* initialize a global variable that C can access to print the nameStr */
.global nameStrPtr
.type nameStrPtr,%gnu_unique_object
nameStrPtr: .word nameStr   /* Assign the mem loc of nameStr to nameStrPtr */

.global packed_Value,a_Multiplicand,b_Multiplier,a_Sign,b_Sign,prod_Is_Neg,a_Abs,b_Abs,abs_Product,final_Product
.type packed_Value,%gnu_unique_object
.type a_Multiplicand,%gnu_unique_object
.type b_Multiplier,%gnu_unique_object
.type a_Sign,%gnu_unique_object
.type b_Sign,%gnu_unique_object
.type prod_Is_Neg,%gnu_unique_object
.type a_Abs,%gnu_unique_object
.type b_Abs,%gnu_unique_object
.type abs_Product,%gnu_unique_object
.type final_Product,%gnu_unique_object

/* NOTE! These are only initialized ONCE, right before the program runs.
 * If you want these to be 0 every time asmMult gets called, you must set
 * them to 0 at the start of your code!
 */
packed_Value:    .word     0  
a_Multiplicand:  .word     0  
b_Multiplier:    .word     0  
a_Sign:          .word     0  
b_Sign:          .word     0 
prod_Is_Neg:     .word     0  
a_Abs:           .word     0  
b_Abs:           .word     0 
abs_Product:     .word     0
final_Product:   .word     0

 /* Tell the assembler that what follows is in instruction memory    */
.text
.align

    
/********************************************************************
function name: asmMult
function description:
     output = asmMult ()
     
where:
     output: 
     
     function description: See Lab Instructions
     
     notes:
        None
          
********************************************************************/    
.global asmMult
.type asmMult,%function
asmMult:   

    /* save the caller's registers, as required by the ARM calling convention */
    push {r4-r11,LR}
 
.if 0
    /* profs test code. */
    mov r0,r0
.endif
    
    /*** STUDENTS: Place your code BELOW this line!!! **************/
    
    /* Foreword -
	    I tried to use functions and the stack as much as I could. Additionaly I went linearly down the list of labels to calculate
	values for, and worked them out. I could of made much more performant code by working on them in different orders, 
	such as calculating sign and abs together.
	    
	    I often used the stack to store a value I would only need again later one time. I could have used the 
	higher registers (r4-r11) more to store data instead of the stack. The stack is likley less performant to push and pop to 
	as compared to a pair of MOV instructions, as the former requires writes to and reads from memory under the hood.  
	
	    Initialization could also be done more efficiently, as the function it branches to could be done in one line after the
	address is set. if we store 0 in a register, say r1, we can then just run STR r1 [r0] after each LDR r0 =label. This requires
	one less instruction for each initialization except the first compared to the subroutine "initAddress0". This approach also
	avoids any overhead produced by branching and the subroutine calling convention. 
	    
	    I wanted to get some practice using subroutines and the stack.
     */
      
    /* initilization of each variable to 0. packed value can be stored immediatly.
     Two instructions are on each line for compactness and readability */
    LDR r1, =packed_Value;    STR r0, [r1]
    push {r0} /* store on stack for convenient retreival after other initialization */
    LDR r0, =a_Multiplicand;  BL initAddress0 /* "initAddress0" is a function that initialized the memory at an adress in r0 to 0. */
    LDR r0, =b_Multiplier;    BL initAddress0
    LDR r0, =a_Sign;          BL initAddress0
    LDR r0, =b_Sign;          BL initAddress0
    LDR r0, =prod_Is_Neg;     BL initAddress0
    LDR r0, =a_Abs;           BL initAddress0
    LDR r0, =b_Abs;           BL initAddress0
    LDR r0, =abs_Product;     BL initAddress0
    LDR r0, =final_Product;   BL initAddress0
    pop {r0} /* retrieve our packed input from the stack. could also be retreived from the label "packed_Value" */
    
    /* --- Unpack A --- */ 
    push {r0} /* function modifies r0, store it to the stack again for Unpack B */
    BL unpackUpper16 /* branch to the function that unpacks the upper 16 bits */
    LDR r1, =a_Multiplicand /* move label adress into r1 in order to store value received from function  */
    STR r0, [r1] /* r0 is set with the desired result from the unpackUpper16 function */
    MOV r4, r0 /* keep available for later calculations. r4 is the lowest register gaurenteed to not be modified by functions due to to the calling convention */
    
    /* --- Unpack B --- */
    pop {r0} /* retreive packed value back from stack to unpack other half */
    BL unpackLower16 /* function unpacks the lower 16 bits */
    LDR r1, =b_Multiplier /* LDR ra =label_address; STR rb, [ra], store something at a memory adress, will not be commented on going forward, common pattern. */
    STR r0, [r1] /* r0 is set with the desired result from the unpackLower16 function */
    MOV r5, r0 /* keep available for later calculations */
    
    /* --- Input Component Signs --- */
    MOV r0, r4 /* moves the stores unpacked component A into r0, as r0 is the input for the getSign function */
    BL getSign /* function gets sign of whatever is in r0. stores it's N flag basically */
    LDR r1, =a_Sign
    STR r0, [r1]
    push {r0} /* store sign of A in stack for easy retreival in later product sign determination */
    MOV r0, r5 /* same as first line in section, but for B. moves B to be in input register for getSign function */
    BL getSign
    LDR r1, =b_Sign
    STR r0, [r1]
    
    /* --- Product Sign --- */
    pop {r1} /* retreive sign of A into r1 */
    /* zero breaks the standard sign logic, and must be dealt with differently. any product that contains 1 or more zeros is "positive". */
    CMP r4, 0 /* is the multiplicand 0? if it is, set r0 to 0 (positive), and skip ahead to where we store it */
    MOVEQ r0, 0 
    BEQ productSignDetermined
    CMP r5, 0 /* is the multiplier 0? if it is, set r0 to 0 (positive), and skip ahead to where we store it */
    MOVEQ r0, 0 
    BEQ productSignDetermined
    /* function call for general product sign determination. only runs if neither operator is 0. output stored to r0 */
    BL determineProductSign
    productSignDetermined: /* r0 will contain either a 0 (positive) or a 1 (negative) when this label is reached */
    LDR r1, =prod_Is_Neg
    STR r0, [r1]
    MOV r6, r0 /* keep available for final product computation. r4 and r5 contain operators */
    
    /* --- Component ABS --- */
    MOV r0, r4 /* multiplicand (operator A) */
    BL ABS /* function computes the absolute value of what is in r0, and stores it in r0 */
    LDR r1, =a_Abs
    STR r0, [r1]
    push {r0} /* store first abs component in the stack, as r0 will be overwritten when computing the second component */
    MOV r0, r5 /* multiplier (operator B) */
    BL ABS
    LDR r1, =b_Abs
    STR r0, [r1]
    
    /* --- Product ABS --- */
    pop {r1} /* retreive first component's abs (multiplicand) */
    BL positiveMultiplyShiftAndAdd /* multiplies two positive values. r0 contains B, while r1 contains A. product is stored in r0 */
    LDR r1, =abs_Product
    STR r0, [r1]
    
    /* --- Final Product --- */
    MOVS r6, r6 /* updates flags for what prod_Is_Neg resulted in */
    NEGNE r0, r0 /* if the product is negative, negate abs result */
    LDR r1, =final_Product
    STR r0, [r1] 
    /* Result is held in r0, as C requires the return value to be in r0, and the procuct is the intended return value */
    
    /* function is complete, branch to done. 
       Otherwise, subroutines would all be ran 1 after another, resulting in a confuzzling output in r0 */
    B done
    
    
    /* --- Subroutines --- */
    
    /* stores 0 in memory of the adress stored in r0  */
    /* PARAMS: r0 is the adress to store the value 0 at */
    /* OUTPUT: None */
initAddress0:
    push {r4-r11,LR} /* preserve caller registers not intended for function use */
    /* function contents */
    MOV r4, 0
    STR r4, [r0]
    /* restore stack and return to caller */
    pop {r4-r11,LR}
    BX LR  
    
    /* moves the upper 16 bits of a 32 bit register into a register, and shifts it to the LSBs. Sign Extends. */
    /* PARAMS: r0 is the register to unpack from */
    /* OUTPUT: r0 is the unpacked output */
unpackUpper16:
    push {r4-r11,LR} /* preserve caller registers not intended for function use */
    /* function contents */
    ASR r0, 16 /* ASR 16 will move the top 16 bits into the lower 16 bits, and extend the sign */
    /* restore stack and return to caller MOV PC, LR is identical in practice to BX LR. Personally, I prefer the latter. */
    pop {r4-r11,LR}
    MOV PC, LR
    
    /* Isolates (Unpacks) the lower 16 bits of a register, performs sign extension */
    /* PARAMS: r0 is the register to unpack from */
    /* OUTPUT: r0 is the unpacked output */
unpackLower16:
    push {r4-r11,LR}
    LSL r0, 16 /* moves into upper portion of register, culling current contents of upper portion */
    ASR r0, 16 /* shifts back down to lower portion, performs sign extension */
    pop {r4-r11,LR}
    BX LR
       
    /* determine the sign of a register */
    /* PARAMS: r0 is the register to determine the sign of */
    /* OUTPUT: r0 contains the sign when returned to caller. 0 is positive, 1 is negative */
getSign:
    push {r4-r11,LR}
    /* compare to 0, will update N flag for contents of r0 */
    CMP r0, 0
    MOV r0, 0 /* default to positive (0) */
    MOVMI r0, 1 /* if the CMP was negative, overwrite to negative (1) */
    pop {r4-r11,LR}
    BX LR
    
    
    /* Determines the sign that results from multiplication from two values input signs
    /* PARAMS: r0 and r1 contain either 0 (positive) or 1 (negative) */
    /* OUTPUT: r0 contains either a 0 (positive) or a 1 (negative) based on the sign outcome of multiplication */
determineProductSign:
    push {r4-r11,LR}
    TEQ r0, r1 /* Exclusive OR, if both are identical, output is positive, if they are different, outcome is negative */
    MOV r0, 0 /* Default to positive */
    MOVNE r0, 1 /* Overwrite if negative */ 
    pop {r4-r11,LR}
    BX LR
       
    /* computes the absolute value of an input */
    /* PARAMS: r0 contains the value to get the absolute value of */ 
    /* OUTPUT: r0 contains the computed ABS */
ABS:
    push {r4-r11,LR}
    push {r0} /* store, r0 is used for sign retrevial and checks */
    /* get the sign */
    BL getSign /* can reuse functionality here, function also takes input in r0, so no movements need to occur. due to also outputting in r0, r0 was stored to stack first */
    /* abs */
    TST r0, 1
    pop {r0} /* flags set from sign, retreive value */
    NEGNE r0, r0 /* negate if flags set from sign indicate negative, will always result in a positive value */
    /* restore stack and return to caller */
    pop {r4-r11,LR}
    BX LR
    
    /* multiplies two positive values using a Shift-and-Add algorithm */
    /* PARAMS: r0 contains the abs of the multiplicand, r1 contains the abs of the multiplier */
    /* OUTPUT: r0 contains the product */
positiveMultiplyShiftAndAdd:
    push {r4-r11,LR}
    MOV r4, 0 /* product register, initialize product to 0 */
    multEQ0: 
    CMP r1, 0 /* check for if the multiplier is 0. multiplication is complete if it is */
    BEQ multComplete
    /* checks and addition */
    TST r1, 0x00000001 /* checks if the last bit of the multiplier is 1, if it is, we add the multiplicand to the product */
    ADDNE r4, r4, r0 /* adds to product if LSB is set */
    /* logical shifts, models how multiplication of large numbers is ussualy done by hand */
    LSR r1, 1 /* shifts the multiplier to the right */
    LSL r0, 1 /* shifts the multiplicand to the left */
    B multEQ0 /* loop, moves to the zero check and repeats */
    multComplete: /* only hit when the multiplier is 0 */
    MOV r0, r4 /* move product into the r0 register, as it is the expected output register */
    pop {r4-r11,LR}
    BX LR
    
    
    /*** STUDENTS: Place your code ABOVE this line!!! **************/

done:    
    mov r0,r0 /* these are do-nothing lines to deal with IDE mem display bug */
    mov r0,r0 

    /* restore the caller's registers, as required by the 
     * ARM calling convention 
     */
    pop {r4-r11,LR}

    mov pc, lr	 /* asmMult return to caller */
   

/**********************************************************************/   
.end  /* The assembler will not process anything after this directive!!! */
           




