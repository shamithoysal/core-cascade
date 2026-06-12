import sys
import re

# ISA Opcode Mapping [15:12]
OPCODES = {
    'NOP': 0x0, 'BR': 0x1, 'CMP': 0x2, 'ADD': 0x3,
    'SUB': 0x4, 'MUL': 0x5, 'DIV': 0x6, 'LDR': 0x7,
    'STR': 0x8, 'CONST': 0x9, 'FIXED_MUL': 0xA,
    'SLL': 0xB, 'SRL': 0xC, 'SRA': 0xD, 'RET': 0xF
}

def parse_reg(reg_str):
    """Converts 'R13' to integer 13"""
    match = re.match(r'R(\d+)', reg_str.strip(), re.IGNORECASE)
    if not match:
        raise ValueError(f"Invalid register format: {reg_str}")
    reg_num = int(match.group(1))
    if reg_num < 0 or reg_num > 15:
        raise ValueError(f"Register out of bounds (0-15): {reg_str}")
    return reg_num

def parse_imm(imm_str):
    """Converts hex (0x...) or decimal strings to an 8-bit integer"""
    imm_str = imm_str.strip()
    if imm_str.lower().startswith('0x'):
        val = int(imm_str, 16)
    else:
        val = int(imm_str)
    
    # Handle negative immediates (2's complement 8-bit)
    if val < 0:
        val = (1 << 8) + val
    return val & 0xFF

def assemble(input_file, output_file):
    with open(input_file, 'r') as f:
        lines = f.readlines()

    instructions = []
    labels = {}

    # PASS 1: Strip comments, empty lines, and record Labels
    current_addr = 0
    for line in lines:
        # Strip comments
        line = line.split('//')[0].strip()
        if not line:
            continue
        
        # Check for Label
        if line.endswith(':'):
            label_name = line[:-1].strip()
            labels[label_name] = current_addr
            continue
            
        instructions.append(line)
        current_addr += 1

    # PASS 2: Assemble instructions into 16-bit hex
    hex_output = []
    for line_num, line in enumerate(instructions):
        parts = line.replace(',', ' ').split()
        mnemonic = parts[0].upper()

        if mnemonic not in OPCODES and not mnemonic.startswith('BR'):
            raise SyntaxError(f"Line {line_num}: Unknown mnemonic '{mnemonic}'")

        # Handle Branch Aliases (e.g., BRnzp, BRp)
        if mnemonic.startswith('BR'):
            nzp_str = mnemonic[2:]
            nzp = 0
            if 'n' in nzp_str or 'N' in nzp_str: nzp |= 0b100
            if 'z' in nzp_str or 'Z' in nzp_str: nzp |= 0b010
            if 'p' in nzp_str or 'P' in nzp_str: nzp |= 0b001
            if nzp == 0: nzp = 0b111 # Default to unconditional
            
            opcode = OPCODES['BR']
            target = parts[1]
            if target in labels:
                imm = labels[target]
            else:
                imm = parse_imm(target)
            
            # Format: [15:12]=1, [11:9]=NZP, [8]=0, [7:0]=Imm
            instr = (opcode << 12) | (nzp << 9) | imm
            hex_output.append(f"{instr:04X}")
            continue

        opcode = OPCODES[mnemonic]

        try:
            if mnemonic in ['NOP', 'RET']:
                instr = (opcode << 12)
            
            elif mnemonic in ['ADD', 'SUB', 'MUL', 'DIV', 'FIXED_MUL', 'SLL', 'SRL', 'SRA']:
                # Format: OP Rd, Rs, Rt
                rd = parse_reg(parts[1])
                rs = parse_reg(parts[2])
                rt = parse_reg(parts[3])
                instr = (opcode << 12) | (rd << 8) | (rs << 4) | rt
            
            elif mnemonic == 'CMP':
                # Format: CMP Rs, Rt (Rd is 0)
                rs = parse_reg(parts[1])
                rt = parse_reg(parts[2])
                instr = (opcode << 12) | (0 << 8) | (rs << 4) | rt
            
            elif mnemonic == 'LDR':
                # Format: LDR Rd, Rs (Rt is 0)
                rd = parse_reg(parts[1])
                rs = parse_reg(parts[2])
                instr = (opcode << 12) | (rd << 8) | (rs << 4) | 0
            
            elif mnemonic == 'STR':
                # Format: STR Rs, Rt (Rd is 0) -> Rs is address, Rt is data
                rs = parse_reg(parts[1])
                rt = parse_reg(parts[2])
                instr = (opcode << 12) | (0 << 8) | (rs << 4) | rt
            
            elif mnemonic == 'CONST':
                # Format: CONST Rd, Imm
                rd = parse_reg(parts[1])
                imm = parse_imm(parts[2])
                instr = (opcode << 12) | (rd << 8) | imm

            hex_output.append(f"{instr:04X}")
        except Exception as e:
            print(f"Error parsing line {line_num}: '{line}' -> {e}")
            sys.exit(1)

    # Pad with NOPs to reach 256 instructions (Program Memory depth)
    while len(hex_output) < 256:
        hex_output.append("0000")

    with open(output_file, 'w') as f:
        f.write('\n'.join(hex_output) + '\n')
    
    print(f"Successfully assembled {len(instructions)} instructions into {output_file}")

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python assembler.py <input.asm> <output.hex>")
        sys.exit(1)
    assemble(sys.argv[1], sys.argv[2])