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
  CovenantTable   newCovs;
  vertex_set_t    blacklist, remlist, entries, covenants; //hashes of all covenants
  vertex_set_map_t covenantsPerVertex;
  std::string optmisedAnalysisReport, covenantReport;


  Graph&          gOri;
  AllocTable&     at;
  GroupTable&     gt;
  CovenantTable&  ct;
  HashMap&        hm;

  void generateModel(); //Graph& gSrc, Graph& gDst, Graph& gStaticEq
  void updateRemlist();
  bool addResidentDestinations();        //adds edges to block for all command nodes reachable by cursors to gWc 
  vertex_set_t getDynamicDestinations(vertex_t vQ); //returns list of vertices mentioned in commands at this block node
  bool addDynamicDestinations();         //adds edges between blocks and command targets vertices from getDynamicDestinations calls to gWc
  bool updateStaleDefaultDestinations(); //gEq, at, newCovs, report
  vertex_set_t getDominantFlowDst(vertex_t vQ); //gEq, at, newCovs, report
  void getReverseNodeTree(vertex_t v, vertex_set_t& sV, vertex_set_map_t& covenantsPerVertex, vertex_t covenant = null_vertex);
                                          // recursively maps the reverse node tree (follow in-edges) starting at vertex v
  bool isOptimisableEdge(edge_t e);       // check if edge is default with overriding flow AND the only connection to its target
  bool isSafetyCritical(vertex_set_t& c); // checks is vertex sequence leads to 
  unsigned cullCovenantTable();           // remove fulfilled covenants from ct
  unsigned amendCovenantTable();          // add the content of newCovs to ct
  void cleanup();
  

public:
  Safe2Remove(Graph& g, AllocTable& at, GroupTable& gt, CovenantTable&  ct, HashMap& hm, vertex_set_t& cursors): 
    g(g), at(atCheck), gt(gt), ct(ct), hm(hm) {generateModel();}
  Safe2Remove(Graph& g, AllocTable& at, GroupTable& gt, CovenantTable&  ct, HashMap& hm, vertex_set_t& cursors, Graph& gToRemove):
    g(g), at(atCheck), gt(gt), ct(ct), hm(hm) {generateModel(); generateRemovals(gToRemove);}
  Safe2Remove(Graph& g, AllocTable& at, GroupTable& gt, CovenantTable&  ct, HashMap& hm, vertex_set_t& cursors, std::string patternToRemove):
    g(g), at(atCheck), gt(gt), ct(ct), hm(hm) {generateModel(); generateRemovals(patternToRemove);}
  Safe2Remove(Graph& g, AllocTable& at, GroupTable& gt, CovenantTable&  ct, HashMap& hm, vertex_set_t& cursors, std::set<std::string> patternToRemove):
    g(g), at(atCheck), gt(gt), ct(ct), hm(hm) {generateModel(); generateRemovals(patternsToRemove);}

  void updateModel() {
    gWc.clear(); gEq.clear();
    generateModel();
  }

    blacklist.clear(); remlist.clear(); entries.clear(); covenantsPerVertex.clear()

  void updateRemovals(Graph& gToRemove);
  void updateRemovals(std::string patternToRemove);
  void updateRemovals(std::set<std::string> patternsToRemove);

  std::pair<unsigned, unsigned> updateCovenantTable() {
    std::pair<unsigned, unsigned> ret; 
    ret.first   = cullCovenantTable();
    ret.second  = amendCovenantTable();
    return ret;
  }

  bool isSafe(); // checks removal against model and cursors. Updates the table of new covenants newCovs

};

#endif


