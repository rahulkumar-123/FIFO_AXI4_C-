import os
import subprocess
import sys

def compile_and_run_cpp():
    print("building c++ model...")
    res = subprocess.run(["g++", "-O2", "model.cpp", "-o", "model"], capture_output=True, text=True)
    if res.returncode != 0:
        print("cpp compile failed:")
        print(res.stderr)
        return False
        
    print("gen vectors...")
    model_exe = "model.exe" if sys.platform == "win32" else "./model"
        
    res = subprocess.run([model_exe, "500"], capture_output=True, text=True)
    if res.returncode != 0:
        print("cpp run failed")
        return False
        
    print(res.stdout)
    return True

def run_verilog_simulation():
    print("checking vlog...")
    try:
        subprocess.run(["vlog", "-version"], capture_output=True, check=True)
    except (subprocess.CalledProcessError, FileNotFoundError):
        print("warn: vlog not found. run manually.")
        return False
        
    print("vlib work...")
    subprocess.run(["vlib", "work"], capture_output=True, text=True)
        
    print("compiling rtl...")
    res = subprocess.run(["vlog", "fifo_sync_axi4s.v", "tb_fifo.v"], capture_output=True, text=True)
    if res.returncode != 0:
        print("rtl compile failed:")
        print(res.stderr)
        return False
        
    print("simulating...")
    res = subprocess.run(["vsim", "-c", "-do", "run -all; quit", "tb_fifo_sync_axi4s"], capture_output=True, text=True)
    if res.returncode != 0:
        print("sim failed:")
        print(res.stdout)
        print(res.stderr)
        return False
        
    print("sim done.")
    return True

def compare_results():
    print("checking txns...")
    
    if not os.path.exists("expected_output.txt"):
        print("err: no expected_output.txt")
        return False
        
    if not os.path.exists("actual_output.txt"):
        print("err: no actual_output.txt")
        return False
        
    with open("expected_output.txt", "r") as f_exp, open("actual_output.txt", "r") as f_act:
        expected_lines = f_exp.readlines()
        actual_lines = f_act.readlines()
        
    # Standardize format (remove surrounding whitespace and enforce lowercase)
    # Note: we do NOT remove intermediate spaces since we now have 3 columns
    expected_lines = [line.strip().lower() for line in expected_lines]
    actual_lines = [line.strip().lower() for line in actual_lines]
    
    if len(expected_lines) != len(actual_lines):
        print(f"mismatch count: exp {len(expected_lines)}, act {len(actual_lines)}")
        return False
        
    errors = 0
    for i, (exp, act) in enumerate(zip(expected_lines, actual_lines)):
        if exp != act:
            print(f"mismatch @ {i}: exp '{exp}', act '{act}'")
            errors += 1
            if errors >= 10:
                print("too many errors. bailing.")
                break
                
    if errors == 0:
        print("OK: all txns matched golden model")
        return True
    else:
        print("FAIL: mismatches found")
        return False

if __name__ == "__main__":
    if compile_and_run_cpp():
        run_verilog_simulation()
        compare_results()

