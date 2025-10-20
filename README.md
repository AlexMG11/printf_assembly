# Custom Printf Implementation

A lightweight printf function implemented in pure x86-64 assembly with zero external dependencies.

## Overview

This project implements a subset of the C standard library's `printf` function entirely in x86-64 assembly language. It makes direct Linux system calls without relying on libc, demonstrating low-level systems programming and the System V AMD64 calling convention.

**Supported format specifiers:**
- `%s` - Null-terminated strings
- `%d` - Signed decimal integers
- `%u` - Unsigned decimal integers  
- `%%` - Literal percent character

**Key features:**
- Variadic argument support (unlimited arguments)
- Direct Linux system calls (no libc)
- Proper NULL pointer handling
- Negative number support
- Minimal memory footprint (33 bytes)

## Architecture

### Memory Layout

| Section | Size | Description |
|---------|------|-------------|
| `.data` | ~25 bytes | Format strings and constants |
| `.bss` | 33 bytes | Output buffers (1-byte char + 32-byte number) |
| `.text` | ~1.5 KB | Executable code |

### Variadic Arguments

The function follows the System V AMD64 ABI for argument passing:

**Register Arguments (1-6):**
```
Argument 1: %rdi (format string)
Argument 2: %rsi
Argument 3: %rdx
Argument 4: %rcx
Argument 5: %r8
Argument 6: %r9
```

**Stack Arguments (7+):**
- Located at `[rbp + 16 + 40 + (n-6)*8]`
- 16 bytes: saved rbp + return address
- 40 bytes: 5 saved callee registers (rbx, r12-r15)

## How It Works

### Format String Parsing

```
1. Read character from format string
2. If regular character → print it
3. If '%' → read next character:
   - 's' → print string argument
   - 'd' → print signed integer
   - 'u' → print unsigned integer
   - '%' → print literal '%'
   - other → print "%?" (unknown specifier)
4. Repeat until null terminator
```

### String Output (`%s`)

```
1. Retrieve pointer from argument list
2. Check if NULL → use "(null)" string
3. Calculate length by scanning for '\0'
4. Write to stdout via syscall
```

### Integer Conversion (`%d` and `%u`)

Converts integers to ASCII using division-based algorithm:

```
1. For %d: check sign, print '-' if negative, negate value
2. Handle zero as special case
3. Build string backwards in buffer:
   - Divide value by 10
   - Remainder becomes digit (+ '0' for ASCII)
   - Quotient becomes new value
   - Repeat until value is 0
4. Write resulting string to stdout
```

**Example:** Converting 1234 to "1234"
```
Step 1: 1234 ÷ 10 = 123 remainder 4  → buffer[31] = '4'
Step 2: 123 ÷ 10 = 12 remainder 3    → buffer[30] = '3'
Step 3: 12 ÷ 10 = 1 remainder 2      → buffer[29] = '2'
Step 4: 1 ÷ 10 = 0 remainder 1       → buffer[28] = '1'
Result: "1234" at buffer[28:31]
```

## Usage Example

### Assembly Code

```asm
.data
    format: .asciz "Hello %s! Number: %d, Unsigned: %u\n"
    name:   .asciz "World"

.text
.global main

main:
    pushq   %rbp
    movq    %rsp, %rbp
    
    # Call: my_printf(format, name, -42, 100)
    movq    $format, %rdi      # arg1: format string
    movq    $name, %rsi        # arg2: "World"
    movq    $-42, %rdx         # arg3: -42
    movq    $100, %rcx         # arg4: 100
    call    my_printf
    
    movq    %rbp, %rsp
    popq    %rbp
    movq    $60, %rax          # exit syscall
    xorq    %rdi, %rdi
    syscall
```

**Output:** `Hello World! Number: -42, Unsigned: 100`

### With Stack Arguments

```asm
.data
    format: .asciz "%d %d %d %d %d %d %d %d\n"

.text
main:
    pushq   %rbp
    movq    %rsp, %rbp
    
    # Push stack arguments (8th, 7th) in reverse order
    pushq   $8                 # 8th argument
    pushq   $7                 # 7th argument
    
    # Load register arguments
    movq    $format, %rdi      # arg1: format string
    movq    $1, %rsi           # arg2: 1
    movq    $2, %rdx           # arg3: 2
    movq    $3, %rcx           # arg4: 3
    movq    $4, %r8            # arg5: 4
    movq    $5, %r9            # arg6: 5
    call    my_printf
    
    addq    $16, %rsp          # Clean up stack arguments
    movq    %rbp, %rsp
    popq    %rbp
    movq    $60, %rax
    xorq    %rdi, %rdi
    syscall
```

**Output:** `1 2 3 4 5 0 7 8` (note: 6th argument missing in example)


## System Call Interface

The implementation uses direct Linux system calls:

**Write System Call:**
```
Syscall number: 1 (sys_write)
Parameters:
  rax = 1              (syscall number)
  rdi = 1              (file descriptor: stdout)
  rsi = buffer_address (pointer to data)
  rdx = byte_count     (number of bytes to write)
```

**Exit System Call:**
```
Syscall number: 60 (sys_exit)
Parameters:
  rax = 60             (syscall number)
  rdi = exit_code      (0 = success)
```

## Implementation Details

### Register Usage

**Preserved across function:**
- `%r12` - Format string pointer
- `%r13` - Argument counter (tracks which arg to use)
- `%r14` - Saved argument 1
- `%r15` - Saved argument 2
- `%rbx` - Saved argument 3

**Temporary:**
- `%rax` - Syscall number, return values, temporary calculations
- `%rdi` - Syscall parameters, temporary calculations
- `%rsi` - Syscall parameters, string pointers
- `%rdx` - Syscall parameters, string lengths
- `%rcx` - Division operations
- `%r8, %r9` - Directly accessed arguments 4-5

### Edge Cases

| Case | Handling |
|------|----------|
| NULL string pointer | Print "(null)" |
| Negative numbers | Print '-' sign, convert absolute value |
| Zero value | Special case: print "0" directly |
| Empty string | Skip printing (length = 0) |
| Unknown format | Print "%?" literally |
| Format ends with '%' | Terminate parsing |



## Limitations

- **Limited format specifiers**: Only `%s`, `%d`, `%u`, `%%`
- **No field width/precision**: Cannot specify padding or decimal places
- **No floating point**: No `%f`, `%e`, `%g` support
- **No hex/octal**: No `%x`, `%o` support
- **Fixed output**: Always writes to stdout (fd 1)
- **No buffering**: Each format item causes a separate syscall
- **Maximum integer size**: 64-bit values only

## Design Decisions

### Why Direct Syscalls?

- **Zero dependencies**: No libc required
- **Educational value**: Demonstrates kernel interface
- **Minimal binary size**: No library linking overhead
- **Full control**: Direct understanding of system interface

### Why Reverse String Building?

Integer-to-ASCII conversion naturally produces digits from least significant to most significant (via division), so building the string backwards in memory is the most efficient approach. This avoids needing to reverse the string afterwards.

### Why Separate Handlers?

Each format specifier has unique requirements:
- Strings need length calculation
- Signed integers need sign handling  
- Unsigned integers can skip sign checks
- Modular design makes the code easier to understand and extend
