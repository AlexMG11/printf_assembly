.data                                       # Read‐only data section
    null_str:   .asciz "(null)"                      # String to print when %s receives NULL pointer
    format:     .asciz "%u %d %s %s %s %s %% %r %%%% %"
    #format:     .asciz "%u %d %s"
                                                     
    name:       .asciz "heheheheh"                        # Test string for %s format specifier
    testminint: .quad -9223372036854775808  # Minimum 64-bit signed integer
    testmaxint: .quad  18446744073709551615  # Maximum

.bss                                        # Uninitialized data section (zero-initialized at runtime)
    chbuf:      .space 1                             # 1-byte buffer for printing single characters
    numbuf:     .space 32                            # 32-byte buffer for integer to ASCII conversion

.text                                       # Code section containing executable instructions
.global main                                   # Make main visible to linker (entry point)



main:
    pushq   %rbp                                     # Save old base pointer (function prologue)
    movq    %rsp, %rbp                               # Set up new base pointer for this frame

    # Example usage of my_printf
   movq    $format, %rdi

    
    movq    $18446744073709551615, %rsi      # 1st
    movq    $-9223372036854775808, %rdx      # 2nd
    movq    $name, %rcx      # 2nd
    movq    $name, %r8      # 3rd
    movq    $name, %r9       # 4th
    #movq    $name, %r9       # 5th
    pushq  $name           # 5th
    # Remaining three integers (6th–8th) on the stack, top to bottom: 8, 7, 6
    # This keeps the stack 16-byte aligned before 'call' (8 from push rbp + 24 here = 32).
    #pushq   $8            # 8th
    #pushq   $7            # 7th
    #pushq   $name           # 6th
    call    my_printf                                # Call custom printf function
    

    movq    %rbp, %rsp                               # Restore stack pointer (function epilogue)
    popq    %rbp                                     # Restore old base pointer
    movq    $60,   %rax                              # System call number 60 = exit
    syscall                                          # Invoke system call to exit program


# my_printf: Custom printf implementation
# Parameters:
#   %rdi = format string pointer
#   %rsi = 1st variadic argument    
#   %rdx = 2nd variadic argument  
#   %rcx = 3rd variadic argument
#   %r8  = 4th variadic argument
#   %r9  = 5th variadic argument
#   stack = 6th+ variadic arguments

my_printf:
    pushq   %rbp                                     # Save caller's base pointer
    movq    %rsp,  %rbp                              # Establish new base pointer for this function

    # Save callee-saved registers that we'll use for preserving arguments
    pushq   %rbx                                     # Save %rbx (will hold arg3)
    pushq   %r12                                     # Save %r12 (will hold format string pointer)
    pushq   %r13                                     # Save %r13 (will hold argument counter)
    pushq   %r14                                     # Save %r14 (will hold arg1)
    pushq   %r15                                     # Save %r15 (will hold arg2)
    
  
    movq    %rdi,  %r12                              # Save format string pointer in r12
    movq    %rsi,  %r14                              # Save 1st variadic arg in r14 (string pointer)
    movq    %rdx,  %r15                              # Save 2nd variadic arg in r15 (unsigned value)
    movq    %rcx,  %rbx                              # Save 3rd variadic arg in rbx
    # Note: %r8 and %r9 dont need saving as they are not used in passing args to syscalls when we write
    
    movq    $1,    %r13                              # Initialize argument counter to 1

# Main parsing loop - iterate through format string character by character
parse_loop:
    movb    (%r12), %al                              # Load current byte from format string into AL
    testb   %al,   %al                               # Test if byte is zero (null terminator)
    je      done                                     # If zero, we've reached end of string - jump to cleanup

    cmpb    $'%',  %al                               # Compare current character with '%'
    jne     print_char                               # If not '%', it's a literal character - print it

    # Handle format specifier (character after '%')
    incq    %r12                                     # Advance format pointer past '%'
    movb    (%r12), %al                              # Load the specifier character
    testb   %al,   %al                               # Check if we hit null terminator
    je      done                                     # If null after '%', malformed string - exit

    # Check which format specifier we have
    cmpb    $'s',  %al                               # Is it %s (string)?
    je      handle_s                                 # Yes - jump to string handler
    cmpb    $'d',  %al                               # Is it %d (signed decimal)?
    je      handle_d                                 # Yes - jump to signed handler
    cmpb    $'u',  %al                               # Is it %u (unsigned decimal)?
    je      handle_u                                 # Yes - jump to unsigned handler
    cmpb    $'%',  %al                               # Is it %% (literal percent)?
    je      handle_percent                           # Yes - jump to percent handler
    
    # Unknown format specifier - print it literally (e.g., %r becomes "%r")
    pushq   %rax                                     # Save the specifier character
    movb    $'%',  chbuf(%rip)                       # Store '%' in character buffer
    movq    $1,    %rax                              # System call number 1 = write
    movq    $1,    %rdi                              # File descriptor 1 = stdout
    leaq    chbuf(%rip), %rsi                        # Load address of character buffer
    movq    $1,    %rdx                              # Write 1 byte
    syscall                                          # Invoke write system call
    popq    %rax                                     # Restore the specifier character
    movb    %al,   chbuf(%rip)                       # Store the unknown specifier in buffer
    movq    $1,    %rax                              # System call number 1 = write
    movq    $1,    %rdi                              # File descriptor 1 = stdout
    leaq    chbuf(%rip), %rsi                        # Load address of character buffer
    movq    $1,    %rdx                              # Write 1 byte
    syscall                                          # Invoke write system call
    incq    %r12                                     # Advance format pointer past specifier
    jmp     parse_loop                               # Continue parsing

# Print a single literal character (not a format specifier)
print_char:
    movb    %al,   chbuf(%rip)                       # Store character in buffer
    movq    $1,    %rax                              # System call number 1 = write
    movq    $1,    %rdi                              # File descriptor 1 = stdout
    leaq    chbuf(%rip), %rsi                        # Load address of character buffer
    movq    $1,    %rdx                              # Write 1 byte
    syscall                                          # Invoke write system call
    incq    %r12                                     # Advance format pointer to next character
    jmp     parse_loop                               # Continue parsing

# Handle %% - print a single '%' character
handle_percent:
    movb    $'%',  chbuf(%rip)                       # Store '%' in character buffer
    movq    $1,    %rax                              # System call number 1 = write
    movq    $1,    %rdi                              # File descriptor 1 = stdout
    leaq    chbuf(%rip), %rsi                        # Load address of character buffer
    movq    $1,    %rdx                              # Write 1 byte
    syscall                                          # Invoke write system call
    incq    %r12                                     # Skip past the second '%'
    jmp     parse_loop                               # Continue parsing


handle_s:
    # Determine which argument to use based on argument counter
    cmpq    $1,    %r13                              # Is this the 1st variadic argument?
    jne     .s_check2                                # No - check next
    movq    %r14,  %rsi                              # Yes - load arg1 from r14 (where we saved it)
    jmp     .s_got_ptr                               # Got the pointer, continue

.s_check2:
    cmpq    $2,    %r13                              # Is this the 2nd variadic argument?
    jne     .s_check3                                # No - check next
    movq    %r15,  %rsi                              # Yes - load arg2 from r15
    jmp     .s_got_ptr                               # Got the pointer, continue

.s_check3:
    cmpq    $3,    %r13                              # Is this the 3rd variadic argument?
    jne     .s_check4                                # No - check next
    movq    %rbx,  %rsi                              # Yes - load arg3 from rbx
    jmp     .s_got_ptr                               # Got the pointer, continue

.s_check4:
    cmpq    $4,    %r13                              # Is this the 4th variadic argument?
    jne     .s_check5                                # No - check next
    movq    %r8,   %rsi                              # Yes - load arg4 from r8
    jmp     .s_got_ptr                               # Got the pointer, continue

.s_check5:
    cmpq    $5,    %r13                              # Is this the 5th variadic argument?
    jne     .s_stack                                 # No - must be on stack
    movq    %r9,   %rsi                              # Yes - load arg5 from r9
    jmp     .s_got_ptr                               # Got the pointer, continue

.s_stack:
    # Arguments 6+ are on the stack above our saved registers
    movq    %r13,  %rax                              # Copy argument index to rax
    subq    $6,    %rax                              # Subtract 6 to get stack argument index (0-based)
    shlq    $3,    %rax                              # Multiply by 8 (shift left 3 bits) for byte offset
    addq    $16,   %rax                              # Add 16 to skip saved rbp (8) + return address (8)
    
    movq    (%rbp,%rax), %rsi                        # Load argument from calculated stack position

.s_got_ptr:
    incq    %r13                                     # Increment argument counter for next time
    
    # Check if string pointer is NULL   
    testq   %rsi,  %rsi                              # Test if pointer is zero (NULL)
    jne     .s_not_null                              # If not NULL, continue with string
    leaq    null_str(%rip), %rsi                     # If NULL, use "(null)" string instead
    
.s_not_null:
    # Calculate string length by scanning for null terminator
    #pushq   %rsi                                     # Save string pointer for later use
    xorq    %rdx,  %rdx                              # Clear rdx (will be our length counter)

.s_len:
    movb    (%rsi,%rdx), %al                         # Load byte at string[rdx] into al
    testb   %al,   %al                               # Test if byte is zero (null terminator)
    je      .s_print                                 # If zero, we found the end - go print
    incq    %rdx                                     # Increment length counter
    jmp     .s_len                                   # Continue scanning
    
.s_print:
    #popq    %rsi                                     # Restore string pointer
    testq   %rdx,  %rdx                              # Check if length is zero (empty string)
    je      .s_done                                  # If empty, skip printing
    movq    $1,    %rax                              # System call number 1 = write
    movq    $1,    %rdi                              # File descriptor 1 = stdout
    # %rsi already contains string pointer            # Buffer address is already in rsi
    # %rdx already contains string length             # Length is already in rdx
    syscall                                          # Invoke write system call
    
.s_done:
    incq    %r12                                     # Advance format pointer past 's'
    jmp     parse_loop                               # Continue parsing


handle_u:
    # Determine which argument to use based on argument counter (same pattern as %s)
    cmpq    $1,    %r13                              # Is this the 1st variadic argument?
    jne     .u_check2                                # No - check next
    movq    %r14,  %rax                              # Yes - load arg1 from r14
    jmp     .u_got_val                              # Got the value, continue

.u_check2:
    cmpq    $2,    %r13                              # Is this the 2nd variadic argument?
    jne     .u_check3                                # No - check next
    movq    %r15,  %rax                              # Yes - load arg2 from r15 (this is our 10)
    jmp     .u_got_val                               # Got the value, continue

.u_check3:
    cmpq    $3,    %r13                              # Is this the 3rd variadic argument?
    jne     .u_check4                                # No - check next
    movq    %rbx,  %rax                              # Yes - load arg3 from rbx
    jmp     .u_got_val                              # Got the value, continue

.u_check4:
    cmpq    $4,    %r13                              # Is this the 4th variadic argument?
    jne     .u_check5                                # No - check next
    movq    %r8,   %rax                              # Yes - load arg4 from r8
    jmp     .u_got_val                               # Got the value, continue

.u_check5:
    cmpq    $5,    %r13                              # Is this the 5th variadic argument?
    jne     .u_stack                                 # No - must be on stack
    movq    %r9,   %rax                              # Yes - load arg5 from r9
    jmp     .u_got_val                               # Got the value, continue

.u_stack:
    # Arguments 6+ are on the stack
    pushq   %rdx                                     # Save rdx (we need it for calculation)
    movq    %r13,  %rdx                              # Copy argument index
    subq    $6,    %rdx                              # Subtract 6 for stack argument index
    shlq    $3,    %rdx                              # Multiply by 8 for byte offset
    addq    $16,   %rdx                              # Skip saved rbp + return address
    
    movq    (%rbp,%rdx), %rax                        # Load argument from stack
    popq    %rdx                                     # Restore rdx

.u_got_val:
    incq    %r13                                     # Increment argument counter
    
    # Convert unsigned integer to ASCII string (builds string backwards)
    leaq    numbuf+31(%rip), %rsi                    # Point to last byte of number buffer
    movb    $0,    (%rsi)                            # Store null terminator at end
    decq    %rsi                                     # Move back one byte
    
    # Handle special case: value is zero
    testq   %rax,  %rax                              # Check if value is zero
    jne     .u_convert                               # If not zero, do conversion
    movb    $'0',  (%rsi)                            # Store ASCII '0'
    jmp     .u_print                                 # Skip to printing
    
.u_convert:
    pushq   %rbx                                     # Save rbx (we'll use it for the value)
    movq    %rax,  %rbx                              # Copy value to rbx

.u_loop:
    testq   %rbx,  %rbx                              # Check if value is zero
    je      .u_done_convert                          # If zero, we're done converting
    movq    %rbx,  %rax                              # Copy current value to rax for division
    xorq    %rdx,  %rdx                              # Clear rdx (high 64 bits of dividend)
    movq    $10,   %rcx                              # Divisor = 10
    divq    %rcx                                     # Divide rax by 10: q- rax, r - rdx
    movq    %rax,  %rbx                              # Save quotient back to rbx
    addb    $'0',  %dl                               # Convert remainder (0-9) to ASCII ('0'-'9')
    movb    %dl,   (%rsi)                            # Store ASCII digit in buffer
    decq    %rsi                                     # Move back one byte in buffer
    jmp     .u_loop                                  # Continue with next digit
    
.u_done_convert:
    incq    %rsi                                     # Move forward to first digit
    popq    %rbx                                     # Restore rbx
    
.u_print:
    # Calculate length of number string
    leaq    numbuf+31(%rip), %rdx                    # Point to end of buffer (null terminator)
    subq    %rsi,  %rdx                              # Subtract start position to get length
    
    movq    $1,    %rax                              # System call number 1 = write
    movq    $1,    %rdi                              # File descriptor 1 = stdout
    # %rsi already points to start of number string   # Buffer address is already in rsi
    # %rdx already contains length                    # Length is already in rdx
    syscall                                          # Invoke write system call
    
    incq    %r12                                     # Advance format pointer past 'u'
    jmp     parse_loop                               # Continue parsing


handle_d:
    # Get the signed argument (same pattern as %u)
    cmpq    $1,    %r13                              # Is this the 1st variadic argument?
    jne     .d_check2                                # No - check next
    movq    %r14,  %rax                              # Yes - load arg1 from r14
    jmp     .d_got_val                               # Got the value, continue

.d_check2:
    cmpq    $2,    %r13                              # Is this the 2nd variadic argument?
    jne     .d_check3                                # No - check next
    movq    %r15,  %rax                              # Yes - load arg2 from r15
    jmp     .d_got_val                               # Got the value, continue

.d_check3:
    cmpq    $3,    %r13                              # Is this the 3rd variadic argument?
    jne     .d_check4                                # No - check next
    movq    %rbx,  %rax                              # Yes - load arg3 from rbx
    jmp     .d_got_val                               # Got the value, continue

.d_check4:
    cmpq    $4,    %r13                              # Is this the 4th variadic argument?
    jne     .d_check5                                # No - check next
    movq    %r8,   %rax                              # Yes - load arg4 from r8
    jmp     .d_got_val                               # Got the value, continue

.d_check5:
    cmpq    $5,    %r13                              # Is this the 5th variadic argument?
    jne     .d_stack                                 # No - must be on stack
    movq    %r9,   %rax                              # Yes - load arg5 from r9
    jmp     .d_got_val                               # Got the value, continue

.d_stack:
    pushq   %rdx                                     # Save rdx for calculation
    movq    %r13,  %rdx                              # Copy argument index
    subq    $6,    %rdx                              # Subtract 6 for stack argument index
    shlq    $3,    %rdx                              # Multiply by 8 for byte offset
    addq    $16,   %rdx                              # Skip saved rbp + return address
    
    movq    (%rbp,%rdx), %rax                        # Load argument from stack
    popq    %rdx                                     # Restore rdx

.d_got_val:
    incq    %r13                                     # Increment argument counter
    
    # Check if value is negative
    cmpq $0,%rax
    jge .d_positive
    
    # Handle negative number: print minus sign first
    pushq   %rax                                     # Save the negative value
    movb    $'-',  chbuf(%rip)                       # Store '-' in character buffer
    movq    $1,    %rax                              # System call number 1 = write
    movq    $1,    %rdi                              # File descriptor 1 = stdout
    leaq    chbuf(%rip), %rsi                        # Load address of character buffer
    movq    $1,    %rdx                              # Write 1 byte
    syscall                                          # Invoke write system call
    popq    %rax                                     # Restore the negative value
    negq    %rax                                     # Negate to make it positive for conversion
    
.d_positive:
    # Convert to string (same as unsigned conversion)
    leaq    numbuf+31(%rip), %rsi                    # Point to last byte of buffer
    movb    $0,    (%rsi)                            # Store null terminator
    decq    %rsi                                     # Move back one byte
    
    testq   %rax,  %rax                              # Check if value is zero
    jne     .d_convert                               # If not zero, do conversion
    movb    $'0',  (%rsi)                            # Store ASCII '0'
    jmp     .d_print                                 # Skip to printing
    
.d_convert:
    pushq   %rbx                                     # Save rbx
    movq    %rax,  %rbx                              # Copy value to rbx

.d_loop:
    testq   %rbx,  %rbx                              # Check if value is zero
    je      .d_done_convert                          # If zero, done converting
    movq    %rbx,  %rax                              # Copy value for division
    xorq    %rdx,  %rdx                              # Clear high 64 bits - zero it out
    movq    $10,   %rcx                              # Divisor = 10
    divq    %rcx                                     # Divide: q- rax, r -rdx
    movq    %rax,  %rbx                              # Save quotient
    addb    $'0',  %dl                               # Convert digit to ASCII
    movb    %dl,   (%rsi)                            # Store in buffer
    decq    %rsi                                     # Move back in buffer
    jmp     .d_loop                                  # Continue with next digit
    
.d_done_convert:
    incq    %rsi                                     # Move to first digit
    popq    %rbx                                     # Restore rbx
    
.d_print:
    leaq    numbuf+31(%rip), %rdx                    # Point to end of buffer
    subq    %rsi,  %rdx                              # Calculate length
    movq    $1,    %rax                              # System call number 1 = write
    movq    $1,    %rdi                              # File descriptor 1 = stdout
    # %rsi and %rdx already set                      # Buffer and length ready
    syscall                                          # Invoke write system call
    
    incq    %r12                                     # Advance format pointer past 'd'
    jmp     parse_loop                               # Continue parsing


done:
    # Restore all callee-saved registers in reverse order
    popq    %r15                                     # Restore r15
    popq    %r14                                     # Restore r14
    popq    %r13                                     # Restore r13
    popq    %r12                                     # Restore r12
    popq    %rbx                                     # Restore rbx
    
    popq    %rbp                                     # Restore caller's base pointer
    ret                                              # Return to caller