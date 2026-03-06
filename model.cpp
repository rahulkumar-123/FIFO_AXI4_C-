#include <cstdint>
#include <cstdlib>
#include <ctime>
#include <fstream>
#include <iostream>
#include <queue>
#include <vector>


using namespace std;

struct AxiStreamData {
  uint32_t tdata;
  uint8_t tkeep;
  uint8_t tlast;
};

int main(int argc, char **argv) {
  int tx_count = 100;
  if (argc >= 2) tx_count = atoi(argv[1]);

  srand(time(NULL));

  queue<AxiStreamData> ideal_fifo;
  vector<AxiStreamData> in_seq;
  vector<AxiStreamData> out_seq;

  // build random stream bursts
  for (int i = 0; i < tx_count; ++i) {
    AxiStreamData data;
    // shift to avoid RAND_MAX limits on windows
    data.tdata = ((rand() & 0xFFFF) << 16) | (rand() & 0xFFFF);
    data.tlast = (rand() % 10 == 0) ? 1 : 0; 
    
    // calc keep mask - usually full F, but partial on last beat
    if (data.tlast) {
        int vbytes = (rand() % 4) + 1; 
        data.tkeep = (1 << vbytes) - 1; 
    } else {
        data.tkeep = 0xF;
    }
    
    in_seq.push_back(data);
  }

  // push through ideal queue
  for (const auto &d : in_seq) ideal_fifo.push(d);

  while (!ideal_fifo.empty()) {
    out_seq.push_back(ideal_fifo.front());
    ideal_fifo.pop();
  }

  // dump inputs
  ofstream in_file("input_vectors.txt");
  if (!in_file.is_open()) return 1;
  
  for (const auto &d : in_seq) {
    in_file << hex << d.tdata << " " << hex << (int)d.tkeep << " " << (int)d.tlast << endl;
  }
  in_file.close();

  // expected outs
  ofstream out_file("expected_output.txt");
  if (!out_file.is_open()) return 1;
  
  for (const auto &d : out_seq) {
    out_file << hex << d.tdata << " " << hex << (int)d.tkeep << " " << (int)d.tlast << endl;
  }
  out_file.close();

  cout << "dumped " << tx_count << " txns\n";
  return 0;
}
