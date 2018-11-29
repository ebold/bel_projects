#ifndef _DOT_IO_H_
#define _DOT_IO_H_

#include <stdlib.h>
#include <string>
#include "graph.h"


class DotIO {

private:
  // Text File IO /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

public:
// Graphs to Dot
  static boost::dynamic_properties createParser (Graph& g);
  static void writeTextFile (const std::string& fn, const std::string& s);
  static std::string readTextFile (const std::string& fn);
  static Graph& parseDot (const std::string& s, Graph& g); //Parse a .dot string to create unprocessed Graph
  static std::string createDot (Graph& g, bool filterMeta);
  static void writeDotFile (const std::string& fn, Graph& g, bool filterMeta);

};

#endif