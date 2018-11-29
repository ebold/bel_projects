#include <stdlib.h>
#include <stdint.h>
#include <stdio.h>
#include <iostream>
#include <string>
#include <inttypes.h>
#include <boost/graph/graphviz.hpp>
#include "graph.h"
#include "common.h"

#include "dotio.h"
#include "hashmap.h"
#include "dotstr.h"
#include "propwrite.h"


namespace dgp = DotStr::Graph::Prop;
namespace dnp = DotStr::Node::Prop;
namespace dep = DotStr::Edge::Prop;


boost::dynamic_properties DotIO::createParser(Graph& g) {

    boost::dynamic_properties dp(boost::ignore_other_properties);
    boost::ref_property_map<Graph *, std::string> gname( boost::get_property(g, boost::graph_name));
    dp.property(dgp::sName,     gname);
    dp.property(dep::Base::sType,               boost::get(&myEdge::type,         g));
    dp.property(dnp::Base::sName,               boost::get(&myVertex::name,       g));
    dp.property(dnp::Base::sCpu,                boost::get(&myVertex::cpu,        g));

    dp.property(dnp::Base::sType,               boost::get(&myVertex::type,       g));
    dp.property(dnp::Base::sFlags,              boost::get(&myVertex::flags,      g));
    dp.property(dnp::Base::sPatName,            boost::get(&myVertex::patName,    g));
    dp.property(dnp::Base::sPatEntry,           boost::get(&myVertex::patEntry,   g));
    dp.property(dnp::Base::sPatExit,            boost::get(&myVertex::patExit,    g));
    dp.property(dnp::Base::sBpName,             boost::get(&myVertex::bpName,     g));
    dp.property(dnp::Base::sBpEntry,            boost::get(&myVertex::bpEntry,    g));
    dp.property(dnp::Base::sBpExit,             boost::get(&myVertex::bpExit,     g));
    //Block
    dp.property(dnp::Block::sTimePeriod,        boost::get(&myVertex::tPeriod,    g));
    dp.property(dnp::Block::sGenQPrioHi,        boost::get(&myVertex::qIl,        g));
    dp.property(dnp::Block::sGenQPrioMd,        boost::get(&myVertex::qHi,        g));
    dp.property(dnp::Block::sGenQPrioLo,        boost::get(&myVertex::qLo,        g));
    //Timing Message
    dp.property(dnp::TMsg::sTimeOffs,           boost::get(&myVertex::tOffs,      g));
    dp.property(dnp::TMsg::sId,                 boost::get(&myVertex::id,         g));
      //ID sub fields
    dp.property(dnp::TMsg::SubId::sFid,         boost::get(&myVertex::id_fid,     g));
    dp.property(dnp::TMsg::SubId::sGid,         boost::get(&myVertex::id_gid,     g));
    dp.property(dnp::TMsg::SubId::sEno,         boost::get(&myVertex::id_evtno,   g));
    dp.property(dnp::TMsg::SubId::sSid,         boost::get(&myVertex::id_sid,     g));
    dp.property(dnp::TMsg::SubId::sBpid,        boost::get(&myVertex::id_bpid,    g));
    dp.property(dnp::TMsg::SubId::sBin,         boost::get(&myVertex::id_bin,     g));
    dp.property(dnp::TMsg::SubId::sReqNoB,      boost::get(&myVertex::id_reqnob,  g));
    dp.property(dnp::TMsg::SubId::sVacc,        boost::get(&myVertex::id_vacc,    g));
    dp.property(dnp::TMsg::sPar,                boost::get(&myVertex::par,        g));
    dp.property(dnp::TMsg::sTef,                boost::get(&myVertex::tef,        g));
    //Command
    dp.property(dnp::Cmd::sTimeValid,           boost::get(&myVertex::tValid,     g));
    dp.property(dnp::Cmd::sVabs,                boost::get(&myVertex::vabs,       g));
    dp.property(dnp::Cmd::sPrio,                boost::get(&myVertex::prio,       g));
    dp.property(dnp::Cmd::sQty,                 boost::get(&myVertex::qty,        g));
    dp.property(dnp::Cmd::sTimeWait,            boost::get(&myVertex::tWait,      g));
    dp.property(dnp::Cmd::sPermanent,           boost::get(&myVertex::perma,      g));

    //for .dot-cmd abuse
    dp.property(dnp::Cmd::sTarget,              boost::get(&myVertex::cmdTarget,  g));
    dp.property(dnp::Cmd::sDst,                 boost::get(&myVertex::cmdDest,    g));
    dp.property(dnp::Cmd::sDstPattern,          boost::get(&myVertex::cmdDestPat, g));
    dp.property(dnp::Cmd::sDstBeamproc,         boost::get(&myVertex::cmdDestBp,  g));
    dp.property(dnp::Base::sThread,             boost::get(&myVertex::thread,     g));

    return (const boost::dynamic_properties)dp;
  }


  std::string DotIO::readTextFile(const std::string& fn) {
    std::string ret;
    std::ifstream in(fn);
    if(in.good()) {
      std::stringstream buffer;
      buffer << in.rdbuf();
      ret = buffer.str();
    }
    else {throw std::runtime_error(" Could not read from file '" + fn + "'");}

    return ret;
  }

  Graph& DotIO::parseDot(const std::string& s, Graph& g) {
    boost::dynamic_properties dp = createParser(g);

    try { boost::read_graphviz(s, g, dp, dnp::Base::sName); }
    catch(...) { throw; }

    BOOST_FOREACH( vertex_t v, vertices(g) ) { g[v].hash = HashMap::hash(g[v].name); } //generate hash to complete vertex information

    return g;
  }

    void DotIO::writeDotFile(const std::string& fn, Graph& g, bool filterMeta) { writeTextFile(fn, createDot(g, filterMeta)); }

     //write out dotstringfrom download graph
  std::string DotIO::createDot(Graph& g, bool filterMeta) {
    std::ostringstream out;
    typedef boost::property_map< Graph, node_ptr myVertex::* >::type NpMap;

    boost::filtered_graph <Graph, boost::keep_all, non_meta<NpMap> > fg(g, boost::keep_all(), make_non_meta(boost::get(&myVertex::np, g)));
    try {

        if (filterMeta) {
          boost::write_graphviz(out, fg, make_vertex_writer(boost::get(&myVertex::np, fg)),
                      make_edge_writer(boost::get(&myEdge::type, fg)), sample_graph_writer{DotStr::Graph::sDefName},
                      boost::get(&myVertex::name, fg));
        }
        else {

          boost::write_graphviz(out, g, make_vertex_writer(boost::get(&myVertex::np, g)),
                      make_edge_writer(boost::get(&myEdge::type, g)), sample_graph_writer{DotStr::Graph::sDefName},
                      boost::get(&myVertex::name, g));
        }
      }
      catch(...) {throw;}

    return out.str();
  }

  //write out dotfile from download graph of a memunit
  void DotIO::writeTextFile(const std::string& fn, const std::string& s) {
    std::ofstream out(fn);
    if(out.good()) { out << s; }
    else {throw std::runtime_error(" Could not write to .dot file '" + fn + "'"); return;}

  }  