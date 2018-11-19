#include <caml/mlvalues.h>
#include <caml/memory.h>
#include <vector>
#include <iostream>
#include "graph.h"

class sigPred {
  public:
    sigPred(value str, std::vector<prop>& label, std::vector<int>& pred_pos, size_t& next_pos) {
      CAMLparam1(str);
      CAMLlocal3(head, propList, predList);

      sig.resize(Int_val(Field(str, 0))+1); /* Resize to respective universe size */
      propList = Field(str, 1);

      while (propList != Val_emptylist) {
        head = Field(propList, 0);        /* hd propList Type: (int * int list) */
        propList = Field(propList, 1);    /* tl propList */
        predList = Field(head, 1);

        size_t predi = Int_val(Field(head, 0));
        if (predi >= pred_pos.size()){
          pred_pos.resize(predi + 1, -1);
        }
        if (pred_pos[predi] == -1){
          pred_pos[predi] = next_pos++;
        }
        predi = pred_pos[predi];

        prop tmp = prop(predi);
        while (predList != Val_emptylist){
          head = Field(predList, 0);
          int arg = Int_val(head);
          tmp.vars.push_back(arg);

          if (sig[arg].size() * 32 <= predi){
            sig[arg].resize(predi / 32 + 1, 0);
          }
          sig[arg][predi/32] |= 1 << (predi % 32);

          predList = Field(predList, 1);
        }
        if (tmp.vars.size() >= 2){
          label.push_back(tmp);
        }
      }
      CAMLreturn0;
    }

    bool sig_lt(size_t a, const sigPred& other, size_t b) const {
      bool ret = other.sig[b].size() >= sig[a].size();
      for (size_t i = 0; ret && i < sig[a].size(); ++i) {
        ret = ret && ((sig[a][i] & sig[b][i]) == sig[a][i]);
      }
      return ret;
    }

  private:
    std::vector<std::vector<uint32_t>> sig;
};
