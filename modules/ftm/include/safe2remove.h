#ifndef _SAFE2REMOVE_H_
#define _SAFE2REMOVE_

#include <stdlib.h>
#include <string>
#include "graph.h"

#include "alloctable.h"
#include "covenanttable.h"


class Safe2Remove {

private:

  //dummyName& data;


  Graph           gWc
  Graph           gEq;

  AllocTable&     atc;
  GroupTable&     gt;
  CovenantTable&  ct;
  HashMap&        hm;

  bool addResidentDestinations(Graph& gEq,  Graph& gOrig, vertex_set_t cursors);
  bool addDynamicDestinations(Graph& g, AllocTable& at);
  bool updateStaleDefaultDestinations(Graph& g, AllocTable& at, CovenantTable& cov, std::string& qAnalysis);
  vertex_set_t getDominantFlowDst(vertex_t vQ, Graph& g, AllocTable& at, CovenantTable& covTab, std::string& qAnalysis);
  vertex_set_t getDynamicDestinations(vertex_t vQ, Graph& g, AllocTable& at);
  vertex_set_t readCursors(vertex_t vQ, Graph& g, AllocTable& at);
  void getReverseNodeTree(vertex_t v, vertex_set_t& sV, Graph& g, vertex_set_map_t& covenantsPerVertex, vertex_t covenant = null_vertex);
  bool isOptimisableEdge(edge_t e, Graph& g);
  bool isSafetyCritical(vertex_set_t& covenants);
  void cleanup();
  unsigned updateCovenants();
  

public:
  //Safe2Remove(dummyName& d)  : gc(d.down.g),  atc(d.down.at), gt(d.gt), ct(d.ct), hm(d.hm) {}
  Safe2Remove(AllocTable& atCheck, GroupTable& gt, CovenantTable&  ct, HashMap& hm)  : atc(atCheck), gt(gt), ct(ct), hm(hm) {}

  void copyGraphToCheck(Graph& g);


  bool isCovenantPending(const std::string& covName);
  bool isCovenantPending(cmI cov);
  bool isSafeToRemove(std::set<std::string> patterns, std::string& report, std::vector<QueueReport>& vQr);
  bool isSafeToRemove(std::set<std::string> patterns, std::string& report) {std::vector<QueueReport> vQr; return isSafeToRemove(patterns, report, vQr);}

};

#endif


