#ifndef _DUMMY_NAME_H_
#define _DUMMY_NAME_H_

#include <stdlib.h>
#include <string>
#include "graph.h"
#include "alloctable.h"
#include "covenanttable.h"
#include "grouptable.h"


class ManagedGraph {
public:

  AllocTable at;
  Graph g;


  void clear() {}


}


class dummyName {

private:
  HashMap hm;
  GroupTable gt;
  CovenantTable ct;

  ManagedGraph up;
  ManagedGraph down;

public:
  dummyName()  {}


};

#endif  



