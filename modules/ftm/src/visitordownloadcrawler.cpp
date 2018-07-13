#include "visitordownloadcrawler.h"
#include "common.h"
#include "node.h"
#include "block.h"
#include "meta.h"
#include "event.h"
#include "dotstr.h"

namespace dnp = DotStr::Node::Prop;
namespace dnt = DotStr::Node::TypeVal;
namespace dep = DotStr::Edge::Prop;
namespace det = DotStr::Edge::TypeVal;


const std::string VisitorDownloadCrawler::exIntro = "VisitorDownloadCrawler: ";


void VisitorDownloadCrawler::setDefDst() const {
  
  uint32_t auxAdr;
  uint32_t tmpAdr;

  auxAdr = writeBeBytesToLeNumber<uint32_t>(b + NODE_DEF_DEST_PTR);
  tmpAdr = at.adrConv(AdrType::INT, AdrType::MGMT,cpu, auxAdr);

  if (tmpAdr == LM32_NULL_PTR) return;
  // try to lookup address and create edge
  try {
    auto x = at.lookupAdr(cpu, tmpAdr);
    boost::add_edge(v, x->v, myEdge(det::sDefDst), g);
  } catch(...) {
    // it is possible that a covenant will cause carpeDM to intentionally leave an orphaned def dst to avoid contesting the DM's future changes
    // So if there is a covenant registered for the node we're just processing, ignore the exception. Otherwise rethrow
    if (!ct.isOk(ct.lookup(g[v].name))) { throw; }
    else {sLog << "setDefDst: Node <" << g[v].name << "> has an invalid def dst, ignoring because of active covenant" << std::endl;}
  }  

}




void VisitorDownloadCrawler::visit(const Block& el) const {
  Graph::in_edge_iterator in_begin, in_end;
  uint32_t tmpAdr;

  
  tmpAdr = at.adrConv(AdrType::INT, AdrType::MGMT,cpu, writeBeBytesToLeNumber<uint32_t>(b + BLOCK_ALT_DEST_PTR ));
  //if the block has no destination list, set default destination ourself
  if (tmpAdr != LM32_NULL_PTR) { boost::add_edge(v, ((AllocMeta*)&(*(at.lookupAdr(cpu, tmpAdr))))->v, myEdge(det::sDstList), g); }
  else setDefDst();  

  tmpAdr = at.adrConv(AdrType::INT, AdrType::MGMT,cpu, writeBeBytesToLeNumber<uint32_t>(b + BLOCK_CMDQ_IL_PTR ));
  if (tmpAdr != LM32_NULL_PTR) boost::add_edge(v, ((AllocMeta*)&(*(at.lookupAdr(cpu, tmpAdr))))->v, myEdge(det::sQPrio[PRIO_IL]), g);
  tmpAdr = at.adrConv(AdrType::INT, AdrType::MGMT,cpu, writeBeBytesToLeNumber<uint32_t>(b + BLOCK_CMDQ_HI_PTR ));
  if (tmpAdr != LM32_NULL_PTR) boost::add_edge(v, ((AllocMeta*)&(*(at.lookupAdr(cpu, tmpAdr))))->v, myEdge(det::sQPrio[PRIO_HI]), g);
  tmpAdr = at.adrConv(AdrType::INT, AdrType::MGMT,cpu, writeBeBytesToLeNumber<uint32_t>(b + BLOCK_CMDQ_LO_PTR ));
  if (tmpAdr != LM32_NULL_PTR) boost::add_edge(v, ((AllocMeta*)&(*(at.lookupAdr(cpu, tmpAdr))))->v, myEdge(det::sQPrio[PRIO_LO]), g);

}

void VisitorDownloadCrawler::visit(const TimingMsg& el) const  {
  uint32_t flags = g[v].np->getFlags();
  uint32_t tmpAdr;

  setDefDst();

  if (flags & NFLG_TMSG_DYN_ID_SMSK) {
    tmpAdr = at.adrConv(AdrType::EXT, AdrType::MGMT,cpu, (uint32_t)writeBeBytesToLeNumber<uint64_t>(b + TMSG_ID ));
    if (tmpAdr != LM32_NULL_PTR) boost::add_edge(v, ((AllocMeta*)&(*(at.lookupAdr(cpu, tmpAdr))))->v, myEdge(det::sDynId),          g);
  }
  if (flags & NFLG_TMSG_DYN_PAR0_SMSK) {
    tmpAdr = at.adrConv(AdrType::EXT, AdrType::MGMT,cpu, (uint32_t)writeBeBytesToLeNumber<uint64_t>(b + TMSG_PAR ));
    if (tmpAdr != LM32_NULL_PTR) boost::add_edge(v, ((AllocMeta*)&(*(at.lookupAdr(cpu, tmpAdr))))->v, myEdge(det::sDynPar0),          g);
  }
  if (flags & NFLG_TMSG_DYN_PAR1_SMSK) {
    tmpAdr = at.adrConv(AdrType::EXT, AdrType::MGMT,cpu, (uint32_t)(writeBeBytesToLeNumber<uint64_t>(b + TMSG_PAR ) >> 32));
    if (tmpAdr != LM32_NULL_PTR) boost::add_edge(v, ((AllocMeta*)&(*(at.lookupAdr(cpu, tmpAdr))))->v, myEdge(det::sDynPar1),          g);
  }
}

std::pair<uint8_t, AdrType> VisitorDownloadCrawler::createCmd(const Command& el) const {
  uint8_t targetCpu; 
  AdrType adrT;
  uint32_t tmpAdr, auxAdr;
  auxAdr = writeBeBytesToLeNumber<uint32_t>(b + CMD_TARGET );  

  std::tie(targetCpu, adrT) = at.adrClassification(auxAdr);
  targetCpu = (adrT == AdrType::PEER ? targetCpu : cpu); // Internal address type does not know which cpu it belongs to

  setDefDst();
  tmpAdr = at.adrConv(adrT, AdrType::MGMT, targetCpu, auxAdr);
  if (tmpAdr != LM32_NULL_PTR) boost::add_edge(v, ((AllocMeta*)&(*(at.lookupAdr(targetCpu, tmpAdr))))->v, myEdge(det::sCmdTarget),    g);

  return std::make_pair(targetCpu, adrT);
}

void VisitorDownloadCrawler::visit(const Flow& el) const  {
  uint8_t targetCpu; 
  AdrType adrT;
  uint32_t tmpAdr;  

  std::tie(targetCpu, adrT) = createCmd((Command&)el);
  uint32_t rawAdr = writeBeBytesToLeNumber<uint32_t>(b + CMD_FLOW_DEST );
  

  tmpAdr = at.adrConv(AdrType::INT, AdrType::MGMT, targetCpu, rawAdr);

  
  if (tmpAdr != LM32_NULL_PTR) boost::add_edge(v, ((AllocMeta*)&(*(at.lookupAdr(targetCpu, tmpAdr))))->v, myEdge(det::sCmdFlowDst),   g);

}

void VisitorDownloadCrawler::visit(const Flush& el) const {
  createCmd((Command&)el);
}

void VisitorDownloadCrawler::visit(const Noop& el) const {
  createCmd((Command&)el);
}

void VisitorDownloadCrawler::visit(const Wait& el) const {
  createCmd((Command&)el);
}

void VisitorDownloadCrawler::visit(const CmdQMeta& el) const {
  uint32_t tmpAdr;  
  for (ptrdiff_t offs = CMDQ_BUF_ARRAY; offs < CMDQ_BUF_ARRAY_END; offs += _32b_SIZE_) {
    tmpAdr = at.adrConv(AdrType::INT, AdrType::MGMT,cpu, writeBeBytesToLeNumber<uint32_t>(b + offs ));
    if (tmpAdr != LM32_NULL_PTR) {
      auto x = at.lookupAdr(cpu, tmpAdr);
      boost::add_edge(v, x->v, (myEdge){det::sMeta}, g);
    }  
  }
}

void VisitorDownloadCrawler::visit(const CmdQBuffer& el) const {
}

void VisitorDownloadCrawler::visit(const DestList& el) const {
  bool searchParent = true;  
  unsigned hops = 0;
  vertex_t vp, v_child = v;

  //create edge to own possible child
  uint32_t auxAdr = writeBeBytesToLeNumber<uint32_t>(b + NODE_DEF_DEST_PTR);
  uint32_t tmpAdr = at.adrConv(AdrType::INT, AdrType::MGMT, cpu, auxAdr);

  

  if (tmpAdr != LM32_NULL_PTR) {
    auto x = at.lookupAdr(cpu, at.adrConv(AdrType::INT, AdrType::MGMT, cpu, auxAdr));
    boost::add_edge(v, x->v, myEdge(det::sDstList), g);

  }

  // Find parent Block
  while(hops < ((altDstMax + dstListCapacity -1) / dstListCapacity) ) { // max number of hops must be less than max depth of dstLinked List
    std::cout << "reconstructing " << g[v].name << std::endl;
    Graph::in_edge_iterator in_begin, in_end;
    boost::tie(in_begin, in_end) = in_edges(v_child,g);
    if( (in_begin == in_end) || (g[*in_begin].type != det::sDstList) ){break;} // no edges or bad edge type found
    vp = source(*in_begin,g);
    if( g[vp].np->isBlock() ) {searchParent = false; break;} // found the parent block 
    v_child = vp;
    hops++; // count the LL hops. Directly connected means hops == 0
  }
  if(searchParent) throw std::runtime_error(  exIntro + "DstList Node " + g[v].name + " seems to have no ancestor block!\n");

  //add all destination (including default destination (defDstPtr might have changed during runtime) connections from the dest list to the parent block
  uint32_t defAdr;
  bool defaultValid = false;
  std::string sType = det::sAltDst;
  
  defAdr = at.adrConv(AdrType::INT, AdrType::MGMT,cpu, writeBeBytesToLeNumber<uint32_t>((uint8_t*)(at.lookupVertex(vp))->b + NODE_DEF_DEST_PTR));

  for (ptrdiff_t offs = DST_ARRAY; offs < DST_ARRAY_END; offs += _32b_SIZE_) {
    tmpAdr = at.adrConv(AdrType::INT, AdrType::MGMT,cpu, writeBeBytesToLeNumber<uint32_t>(b + offs ));
    // only first level dstLst node can contains default destination
    // if tmpAdr it is the default address, change edge type to det::sDefDst (defdst)
    if ((hops == 0) && (tmpAdr == defAdr)) { sType = det::sDefDst; defaultValid = true;}
    else sType = det::sAltDst;

    if (tmpAdr != LM32_NULL_PTR) {
      try {
        auto x = at.lookupAdr(cpu, tmpAdr);
        boost::add_edge(vp, x->v, (myEdge){sType}, g);
      } catch (...) {
        if (!ct.isOk(ct.lookup(g[vp].name))) { throw; }
        else {sLog << "visitDstList: Node <" << g[vp].name << "> has an invalid def dst, ignoring because of active covenant" << std::endl;}

      }
    }  
  }
  if (!defaultValid) { //default destination was not in alt dest list. that shouldnt happen ... draw it in
    sErr << "!!! DefDest not in AltDestList. Means someone set an arbitrary pointer for DefDest !!!" << std::endl;
    if (defAdr != LM32_NULL_PTR) {
      try {
        auto x = at.lookupAdr(cpu, defAdr);
        boost::add_edge(vp, x->v, (myEdge){det::sBadDefDst}, g);
      } catch(...) {
        boost::add_edge(vp, vp, (myEdge){det::sBadDefDst}, g);
      }
    }
  }
 

}






