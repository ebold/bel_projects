#include <stdlib.h>
#include <stdio.h>
#include "meta.h"
#include "ftm_common.h"






void Meta::serialise(const vAdr &va, uint8_t* b) const {
  Node::serialise(va, b);
};

void CmdQMeta::serialise(const vAdr &va, uint8_t* b) const {
  Meta::serialise(va, b);
  auto startIt = va.begin() + ADR_CMDQ_BUF_ARRAY;
  //FIXME size check !
  for(auto it = startIt; it < va.end(); it++) {
    writeLeNumberToBeBytes(b + (ptrdiff_t)CMDQ_BUF_ARRAY + std::distance(startIt, it) * _32b_SIZE_,  *it); 
  }
   
};

void CmdQBuffer::serialise(const vAdr &va, uint8_t* b) const {
  Meta::serialise(va, b);
};

void DestList::serialise(const vAdr &va, uint8_t* b) const {
  //std::cout << "adr lst len" << va.size() << std::endl;
  Meta::serialise(va, b);

  auto startIt = va.begin() + 1; // first element is our own possible child and was used by node serialiser
  for(auto it = startIt; it < va.end(); it++) {
    writeLeNumberToBeBytes(b + (ptrdiff_t)DST_ARRAY + std::distance(startIt, it) * _32b_SIZE_,  *it); 
  }
  //hexDump("dstlst", (char*)b, _MEM_BLOCK_SIZE );
};

void CmdQMeta::show(void) const {
  CmdQMeta::show(0, "");
};

void CmdQMeta::show(uint32_t cnt, const char* prefix) const {
  char* p;
  if (prefix == nullptr) p = (char*)"";
  else p = (char*)prefix;
  printf("%s***------- %3u -------\n", p, cnt);
};

void CmdQBuffer::show(void) const {
  CmdQBuffer::show(0, "");
};

void CmdQBuffer::show(uint32_t cnt, const char* prefix) const {
  char* p;
  if (prefix == nullptr) p = (char*)"";
  else p = (char*)prefix;
  printf("%s***------- %3u -------\n", p, cnt);
};

void DestList::show(void) const {
  DestList::show(0, "");
};

void DestList::show(uint32_t cnt, const char* prefix) const {
  char* p;
  if (prefix == nullptr) p = (char*)"";
  else p = (char*)prefix;
  printf("%s***------- %3u -------\n", p, cnt);

};

