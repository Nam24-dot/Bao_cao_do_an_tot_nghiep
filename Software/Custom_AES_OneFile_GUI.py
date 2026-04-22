import os
import tkinter as tk
from tkinter import ttk, messagebox, filedialog
from tkinter.scrolledtext import ScrolledText
import binascii

try:
    from Crypto.Cipher import AES
except Exception:
    AES = None

APP_TITLE = "Custom AES Lab"
APP_VERSION = "1.0"

# ====== Secret customization parameters (edit these to define your private variant) ======
CUSTOM_IN_MASK  = bytes.fromhex("13579BDF2468ACE013579BDF2468ACE0")
CUSTOM_OUT_MASK = bytes.fromhex("0F1E2D3C4B5A69788796A5B4C3D2E1F0")
CUSTOM_KEY_MASK = bytes.fromhex("A55AA55A3CC33CC35AA55AA53CC33CC3")
PERM            = [7, 2, 13, 4, 11, 0, 15, 9, 1, 14, 6, 10, 3, 12, 5, 8]
ROT_BYTES       = 3
# =========================================================================================

INV_PERM = [0] * 16
for i, p in enumerate(PERM):
    INV_PERM[p] = i


def xor_bytes(a: bytes, b: bytes) -> bytes:
    return bytes(x ^ y for x, y in zip(a, b))


def permute_block(block: bytes, perm) -> bytes:
    return bytes(block[i] for i in perm)


def rot_left_bytes(block: bytes, n: int) -> bytes:
    n %= 16
    return block[n:] + block[:n]


def rot_right_bytes(block: bytes, n: int) -> bytes:
    n %= 16
    return block[-n:] + block[:-n] if n else block


def clean_hex(s: str) -> str:
    s = s.strip().replace(" ", "").replace("\n", "").replace("\r", "")
    if s.startswith("0x") or s.startswith("0X"):
        s = s[2:]
    return s


def parse_hex_16(label: str, s: str) -> bytes:
    s = clean_hex(s)
    if len(s) != 32:
        raise ValueError(f"{label} phải có đúng 32 ký tự hex (128-bit).")
    try:
        return bytes.fromhex(s)
    except ValueError:
        raise ValueError(f"{label} chứa ký tự không hợp lệ. Chỉ dùng 0-9, a-f.")


def fmt_hex(b: bytes) -> str:
    h = b.hex().upper()
    return " ".join(h[i:i+2] for i in range(0, len(h), 2))


def custom_encrypt_block(key: bytes, plaintext: bytes) -> bytes:
    if AES is None:
        raise RuntimeError("Chưa cài pycryptodome. Hãy chạy: py -m pip install pycryptodome")
    p1 = xor_bytes(plaintext, CUSTOM_IN_MASK)
    p2 = permute_block(p1, PERM)
    k2 = xor_bytes(key, CUSTOM_KEY_MASK)
    p3 = AES.new(k2, AES.MODE_ECB).encrypt(p2)
    p4 = xor_bytes(p3, CUSTOM_OUT_MASK)
    p5 = permute_block(p4, INV_PERM)
    c = rot_left_bytes(p5, ROT_BYTES)
    return c


def custom_decrypt_block(key: bytes, ciphertext: bytes) -> bytes:
    if AES is None:
        raise RuntimeError("Chưa cài pycryptodome. Hãy chạy: py -m pip install pycryptodome")
    c1 = rot_right_bytes(ciphertext, ROT_BYTES)
    c2 = permute_block(c1, PERM)
    c3 = xor_bytes(c2, CUSTOM_OUT_MASK)
    k2 = xor_bytes(key, CUSTOM_KEY_MASK)
    c4 = AES.new(k2, AES.MODE_ECB).decrypt(c3)
    c5 = permute_block(c4, INV_PERM)
    p = xor_bytes(c5, CUSTOM_IN_MASK)
    return p

def u32_from_bytes(b: bytes) -> int:
    return int.from_bytes(b, byteorder="big")


def encode_lui(rd: int, imm20: int) -> int:
    return ((imm20 & 0xFFFFF) << 12) | ((rd & 0x1F) << 7) | 0x37


def encode_i_type(imm12: int, rs1: int, funct3: int, rd: int, opcode: int) -> int:
    return ((imm12 & 0xFFF) << 20) | ((rs1 & 0x1F) << 15) | ((funct3 & 0x7) << 12) | ((rd & 0x1F) << 7) | (opcode & 0x7F)


def encode_s_type(imm12: int, rs2: int, rs1: int, funct3: int, opcode: int) -> int:
    imm = imm12 & 0xFFF
    return ((imm >> 5) << 25) | ((rs2 & 0x1F) << 20) | ((rs1 & 0x1F) << 15) | ((funct3 & 0x7) << 12) | ((imm & 0x1F) << 7) | (opcode & 0x7F)


def load_imm32(rd: int, value: int) -> list[int]:
    value &= 0xFFFFFFFF
    upper = ((value + 0x800) >> 12) & 0xFFFFF
    lower = value & 0xFFF
    return [
        encode_lui(rd, upper),
        encode_i_type(lower, rd, 0x0, rd, 0x13),
    ]


def words_from_block(block: bytes) -> list[int]:
    return [u32_from_bytes(block[i:i + 4]) for i in range(0, 16, 4)]


def hex_line(word: int, comment: str) -> str:
    return f"{word & 0xFFFFFFFF:08X} // {comment}"


def build_risc_aes_hex(key: bytes, block: bytes) -> str:
    lines: list[str] = []

    def emit(word: int, comment: str) -> None:
        lines.append(hex_line(word, f"mem[{len(lines)}]: {comment}"))

    def emit_load(rd: int, value: int, label: str) -> None:
        lui_word, addi_word = load_imm32(rd, value)
        upper = ((value + 0x800) >> 12) & 0xFFFFF
        lower = value & 0xFFF
        emit(lui_word, f"lui x{rd}, 0x{upper:05X} ({label})")
        emit(addi_word, f"addi x{rd}, x{rd}, 0x{lower:03X} -> 0x{value & 0xFFFFFFFF:08X}")

    # x5 = AES base 0x80000000, x10 = LED MMIO base 0xffff0000.
    emit(encode_lui(5, 0x80000), "lui x5, 0x80000 (AES base)")
    emit(encode_lui(10, 0xFFFF0), "lui x10, 0xffff0 (LED base)")

    emit(encode_i_type(1, 0, 0x0, 6, 0x13), "addi x6, x0, 1")
    emit(encode_s_type(0x28, 6, 5, 0x2, 0x23), "sw x6, 0x28(x5) (AES config encrypt)")

    for idx, value in enumerate(words_from_block(key)):
        emit_load(6, value, f"KEY{idx}")
        emit(encode_s_type(0x40 + idx * 4, 6, 5, 0x2, 0x23), f"sw x6, 0x{0x40 + idx * 4:02X}(x5) -> KEY{idx}")

    emit(encode_i_type(1, 0, 0x0, 7, 0x13), "addi x7, x0, 1")
    emit(encode_s_type(0x20, 7, 5, 0x2, 0x23), "sw x7, 0x20(x5) (AES INIT)")
    emit(0x00000013, "nop")
    emit(0x00000013, "nop")
    emit(encode_i_type(0x24, 5, 0x2, 6, 0x03), "wait_key: lw x6, 0x24(x5)")
    emit(encode_i_type(1, 6, 0x7, 6, 0x13), "andi x6, x6, 1")
    emit(0xFE030CE3, "beq x6, x0, wait_key")

    for idx, value in enumerate(words_from_block(block)):
        emit_load(6, value, f"BLOCK{idx}")
        emit(encode_s_type(0x80 + idx * 4, 6, 5, 0x2, 0x23), f"sw x6, 0x{0x80 + idx * 4:02X}(x5) -> BLOCK{idx}")

    emit(encode_i_type(2, 0, 0x0, 7, 0x13), "addi x7, x0, 2")
    emit(encode_s_type(0x20, 7, 5, 0x2, 0x23), "sw x7, 0x20(x5) (AES NEXT)")
    emit(0x00000013, "nop")
    emit(0x00000013, "nop")
    emit(encode_i_type(0x24, 5, 0x2, 6, 0x03), "wait_enc: lw x6, 0x24(x5)")
    emit(encode_i_type(2, 6, 0x7, 6, 0x13), "andi x6, x6, 2")
    emit(0xFE030CE3, "beq x6, x0, wait_enc")
    for idx in range(4):
        emit(encode_i_type(0x0C0 + idx * 4, 5, 0x2, 8, 0x03), f"lw x8, 0x{0x0C0 + idx * 4:02X}(x5) -> RESULT{idx}")
        emit(encode_s_type(idx * 4, 8, 10, 0x2, 0x23), f"sw x8, {idx * 4}(x10) -> LED_RESULT{idx}")
    emit(0x00100073, "ebreak")

    return "\n".join(lines) + "\n"


def update_testbench_expected(tb_path: str, expected: bytes) -> None:
    expected_hex = expected.hex()
    with open(tb_path, "r", encoding="ascii") as f:
        content = f.read()
    import re
    content = re.sub(r"localparam \[127:0\] EXPECTED_AES = 128'h[0-9a-fA-F]{32};",
                     f"localparam [127:0] EXPECTED_AES = 128'h{expected_hex};",
                     content)
    with open(tb_path, "w", encoding="ascii", newline="") as f:
        f.write(content)

class App(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title(f"{APP_TITLE} v{APP_VERSION}")
        self.geometry("980x700")
        self.minsize(900, 650)
        self.configure(bg="#0f172a")
        self._setup_style()
        self._build_ui()

    def _setup_style(self):
        style = ttk.Style(self)
        try:
            style.theme_use("clam")
        except Exception:
            pass
        style.configure("TFrame", background="#0f172a")
        style.configure("Card.TFrame", background="#111827")
        style.configure("Header.TLabel", background="#0f172a", foreground="#E5E7EB", font=("Segoe UI", 22, "bold"))
        style.configure("Sub.TLabel", background="#0f172a", foreground="#94A3B8", font=("Segoe UI", 10))
        style.configure("CardTitle.TLabel", background="#111827", foreground="#F8FAFC", font=("Segoe UI", 11, "bold"))
        style.configure("TLabel", background="#0f172a", foreground="#E5E7EB", font=("Segoe UI", 10))
        style.configure("TButton", font=("Segoe UI", 10, "bold"), padding=10)
        style.map("TButton", background=[("active", "#334155")])
        style.configure("Accent.TButton", font=("Segoe UI", 10, "bold"), padding=10)
        style.configure("TRadiobutton", background="#111827", foreground="#E5E7EB", font=("Segoe UI", 10))
        style.map("TRadiobutton", background=[("active", "#111827")])
        style.configure("TEntry", fieldbackground="#0B1220", foreground="#E5E7EB")

    def _build_ui(self):
        root = ttk.Frame(self, padding=18)
        root.pack(fill="both", expand=True)

        header = ttk.Frame(root)
        header.pack(fill="x", pady=(0, 14))
        ttk.Label(header, text="Custom AES Lab", style="Header.TLabel").pack(anchor="w")
        ttk.Label(
            header,
            text="Giao diện một file để mã hóa / giải mã biến thể AES riêng của bạn.",
            style="Sub.TLabel",
        ).pack(anchor="w", pady=(4, 0))

        card = ttk.Frame(root, style="Card.TFrame", padding=16)
        card.pack(fill="both", expand=True)

        topbar = ttk.Frame(card, style="Card.TFrame")
        topbar.pack(fill="x")
        ttk.Label(topbar, text="Thông tin đầu vào", style="CardTitle.TLabel").pack(side="left")

        mode_wrap = ttk.Frame(card, style="Card.TFrame")
        mode_wrap.pack(fill="x", pady=(16, 8))
        self.mode_var = tk.StringVar(value="enc")
        ttk.Radiobutton(mode_wrap, text="Encrypt", value="enc", variable=self.mode_var).pack(side="left", padx=(0, 16))
        ttk.Radiobutton(mode_wrap, text="Decrypt", value="dec", variable=self.mode_var).pack(side="left")

        self._field(card, "Key (128-bit hex)", "key_text", "00112233445566778899AABBCCDDEEFF")
        self._field(card, "Input block (128-bit hex)", "block_text", "0123456789ABCDEFFEDCBA9876543210")

        btns = ttk.Frame(card, style="Card.TFrame")
        btns.pack(fill="x", pady=(12, 10))
        ttk.Button(btns, text="Chạy", style="Accent.TButton", command=self.run_crypto).pack(side="left")
        ttk.Button(btns, text="Encrypt/Decrypt", command=self.swap_mode).pack(side="left", padx=8)
        ttk.Button(btns, text="Dán kết quả vào input", command=self.paste_output_to_input).pack(side="left", padx=8)
        ttk.Button(btns, text="Tao risc_aes.hex cho CPU", command=self.generate_firmware_file).pack(side="left", padx=8)
        ttk.Button(btns, text="Xóa", command=self.clear_all).pack(side="left", padx=8)
        ttk.Button(btns, text="Lưu TXT", command=self.save_report).pack(side="right")
        ttk.Button(btns, text="Copy kết quả", command=self.copy_output).pack(side="right", padx=(0, 8))

        ttk.Separator(card).pack(fill="x", pady=10)

        ttk.Label(card, text="Kết quả", style="CardTitle.TLabel").pack(anchor="w", pady=(0, 8))
        self.output_var = tk.StringVar()
        out_entry = tk.Entry(
            card,
            textvariable=self.output_var,
            relief="flat",
            bg="#0B1220",
            fg="#22C55E",
            insertbackground="#E5E7EB",
            font=("Consolas", 15, "bold"),
            bd=10,
        )
        out_entry.pack(fill="x", pady=(0, 14))

        ttk.Label(card, text="Chi tiết xử lý", style="CardTitle.TLabel").pack(anchor="w", pady=(0, 8))
        self.log = ScrolledText(
            card,
            height=18,
            bg="#020617",
            fg="#CBD5E1",
            insertbackground="#E5E7EB",
            relief="flat",
            font=("Consolas", 10),
            padx=12,
            pady=12,
        )
        self.log.pack(fill="both", expand=True)
        self._write_intro()

        footer = ttk.Frame(root)
        footer.pack(fill="x", pady=(10, 0))
        ttk.Label(
            footer,
            text="Một file duy nhất • Sửa các hằng CUSTOM_* ở đầu file để đổi chuẩn riêng của bạn",
            style="Sub.TLabel",
        ).pack(anchor="w")

    def _field(self, parent, label, attr_name, default):
        ttk.Label(parent, text=label, style="CardTitle.TLabel").pack(anchor="w", pady=(8, 6))
        text = tk.Text(
            parent,
            height=2,
            bg="#0B1220",
            fg="#E5E7EB",
            insertbackground="#E5E7EB",
            relief="flat",
            font=("Consolas", 12),
            padx=12,
            pady=10,
            wrap="word",
        )
        text.pack(fill="x")
        text.insert("1.0", default)
        setattr(self, attr_name, text)

    def _write_intro(self):
        self.log.delete("1.0", tk.END)
        self.log.insert(tk.END, "Custom AES Lab\n")
        self.log.insert(tk.END, "- Encrypt / Decrypt 1 block 128-bit\n")
        self.log.insert(tk.END, "- Tự nhúng chuẩn riêng qua mask, permutation, rotation\n")
        self.log.insert(tk.END, "- Chỉnh tham số ở đầu file nếu muốn đổi thuật toán\n\n")
        if AES is None:
            self.log.insert(tk.END, "Thiếu thư viện pycryptodome. Chạy lệnh sau trong PowerShell:\n")
            self.log.insert(tk.END, "py -m pip install pycryptodome\n")
        else:
            self.log.insert(tk.END, "Sẵn sàng chạy.\n")

    def swap_mode(self):
        self.mode_var.set("dec" if self.mode_var.get() == "enc" else "enc")

    def clear_all(self):
        self.key_text.delete("1.0", tk.END)
        self.block_text.delete("1.0", tk.END)
        self.output_var.set("")
        self._write_intro()

    def copy_output(self):
        out = self.output_var.get().strip()
        if not out:
            messagebox.showinfo("Thông báo", "Chưa có kết quả để copy.")
            return
        self.clipboard_clear()
        self.clipboard_append(out.replace(" ", ""))
        self.update()
        messagebox.showinfo("Đã copy", "Đã copy kết quả vào clipboard.")

    def paste_output_to_input(self):
        out = self.output_var.get().strip().replace(" ", "")
        if not out:
            messagebox.showinfo("Thông báo", "Chưa có kết quả để dán.")
            return
        self.block_text.delete("1.0", tk.END)
        self.block_text.insert("1.0", out)

    def save_report(self):
        content = self.log.get("1.0", tk.END).strip()
        out = self.output_var.get().strip()
        if not out:
            messagebox.showinfo("Thông báo", "Chưa có dữ liệu để lưu.")
            return
        path = filedialog.asksaveasfilename(
            title="Lưu kết quả",
            defaultextension=".txt",
            filetypes=[("Text file", "*.txt")],
            initialfile="custom_aes_result.txt",
        )
        if not path:
            return
        with open(path, "w", encoding="utf-8") as f:
            f.write(content)
            f.write("\n\nRESULT:\n")
            f.write(out.replace(" ", "") + "\n")
        messagebox.showinfo("Đã lưu", f"Đã lưu file:\n{path}")

    def generate_firmware_file(self):
        try:
            if AES is None:
                raise RuntimeError("Thieu pycryptodome. Cai bang: py -m pip install pycryptodome")

            key = parse_hex_16("Key", self.key_text.get("1.0", tk.END))
            block = parse_hex_16("Input block", self.block_text.get("1.0", tk.END))
            result = custom_encrypt_block(key, block)

            base_dir = os.path.dirname(os.path.abspath(__file__))
            hex_path = os.path.join(base_dir, "risc_aes.hex")
            tb_path = os.path.join(base_dir, "sim", "tb_cpu_aes.sv")

            with open(hex_path, "w", encoding="ascii", newline="") as f:
                f.write(build_risc_aes_hex(key, block))

            if os.path.exists(tb_path):
                update_testbench_expected(tb_path, result)

            self.output_var.set(fmt_hex(result))
            self.log.delete("1.0", tk.END)
            self.log.insert(tk.END, "Da tao firmware cho CPU\n")
            self.log.insert(tk.END, f"Key       : {fmt_hex(key)}\n")
            self.log.insert(tk.END, f"Input     : {fmt_hex(block)}\n")
            self.log.insert(tk.END, f"Expected  : {fmt_hex(result)}\n")
            self.log.insert(tk.END, f"HEX file  : {hex_path}\n")
            self.log.insert(tk.END, f"Testbench : {tb_path}\n")
            self.log.insert(tk.END, "\nHay chay mo phong:\n")
            self.log.insert(tk.END, "powershell -ExecutionPolicy Bypass -File .\\sim\\run_questa_all.ps1\n")
            messagebox.showinfo("Da tao risc_aes.hex", "Da tao risc_aes.hex va cap nhat tb_cpu_aes.sv")
        except Exception as e:
            messagebox.showerror("Loi", str(e))
    def run_crypto(self):
        try:
            key = parse_hex_16("Key", self.key_text.get("1.0", tk.END))
            block = parse_hex_16("Input block", self.block_text.get("1.0", tk.END))
            mode = self.mode_var.get()
            self.log.delete("1.0", tk.END)
            self.log.insert(tk.END, f"Mode      : {'Encrypt' if mode == 'enc' else 'Decrypt'}\n")
            self.log.insert(tk.END, f"Key       : {fmt_hex(key)}\n")
            self.log.insert(tk.END, f"Input     : {fmt_hex(block)}\n\n")

            if mode == "enc":
                p1 = xor_bytes(block, CUSTOM_IN_MASK)
                p2 = permute_block(p1, PERM)
                k2 = xor_bytes(key, CUSTOM_KEY_MASK)
                p3 = AES.new(k2, AES.MODE_ECB).encrypt(p2) if AES else b""
                p4 = xor_bytes(p3, CUSTOM_OUT_MASK) if AES else b""
                p5 = permute_block(p4, INV_PERM) if AES else b""
                result = rot_left_bytes(p5, ROT_BYTES) if AES else b""
                self.log.insert(tk.END, f"Step 1 XOR IN MASK : {fmt_hex(p1)}\n")
                self.log.insert(tk.END, f"Step 2 PERMUTE     : {fmt_hex(p2)}\n")
                self.log.insert(tk.END, f"Step 3 KEY MASKED  : {fmt_hex(k2)}\n")
                if AES:
                    self.log.insert(tk.END, f"Step 4 AES-ECB     : {fmt_hex(p3)}\n")
                    self.log.insert(tk.END, f"Step 5 XOR OUTMASK : {fmt_hex(p4)}\n")
                    self.log.insert(tk.END, f"Step 6 INV PERMUTE : {fmt_hex(p5)}\n")
                    self.log.insert(tk.END, f"Step 7 ROTL BYTES  : {fmt_hex(result)}\n")
            else:
                c1 = rot_right_bytes(block, ROT_BYTES)
                c2 = permute_block(c1, PERM)
                c3 = xor_bytes(c2, CUSTOM_OUT_MASK)
                k2 = xor_bytes(key, CUSTOM_KEY_MASK)
                c4 = AES.new(k2, AES.MODE_ECB).decrypt(c3) if AES else b""
                c5 = permute_block(c4, INV_PERM) if AES else b""
                result = xor_bytes(c5, CUSTOM_IN_MASK) if AES else b""
                self.log.insert(tk.END, f"Step 1 ROTR BYTES  : {fmt_hex(c1)}\n")
                self.log.insert(tk.END, f"Step 2 PERMUTE     : {fmt_hex(c2)}\n")
                self.log.insert(tk.END, f"Step 3 XOR OUTMASK : {fmt_hex(c3)}\n")
                self.log.insert(tk.END, f"Step 4 KEY MASKED  : {fmt_hex(k2)}\n")
                if AES:
                    self.log.insert(tk.END, f"Step 5 AES-ECB     : {fmt_hex(c4)}\n")
                    self.log.insert(tk.END, f"Step 6 INV PERMUTE : {fmt_hex(c5)}\n")
                    self.log.insert(tk.END, f"Step 7 XOR IN MASK : {fmt_hex(result)}\n")

            if AES is None:
                raise RuntimeError("Thiếu pycryptodome. Cài bằng: py -m pip install pycryptodome")

            self.output_var.set(fmt_hex(result))
            self.log.insert(tk.END, "\nRESULT    : " + fmt_hex(result) + "\n")
        except Exception as e:
            messagebox.showerror("Lỗi", str(e))


if __name__ == "__main__":
    app = App()
    app.mainloop()



