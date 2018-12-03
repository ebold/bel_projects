#ifndef _NSTIME_H_
#define _NSTIME_H_

#include <stdlib.h>
#include <stdint.h>

class NsTime : public {

private:
  uint64_t t;

  uint64_t truncateToMultiple(uint64_t &val, uint64_t multiple) {
    uint64_t rem = val % multiple;
    uint64_t res = val / multiple;
    val = rem; 
    return res;
  }

  std::string createStr(std::string& (NsTime::*func)(std::string&)) { std::string ret; (*this.*func)(ret); return ret; }


public:

  //return a copy of the timestamp
  uint64_t num() { return this.t; }

  NsTime &operator+=(NsTime &A, const uint64_t &B)
  {
    A.t += B; 
    return A;                                        
  }

  NsTime &operator-=(NsTime &A, const uint64_t &B)
  {
    A.t -= B; 
    return A;                                        
  }

  NsTime operator+(const NsTime &A, const uint64_t &B)
  {
    NsTime ret = A;
    ret.t += B; 
    return ret;                                        
  }

  int64_t diff(const NsTime &B) {
    return ((int64_t)this.t - (int64_t)B.t); 
  }
  
  int64_t operator-(const NsTime &A, const NsTime &B)
  {
    return ((int64_t)A.t - (int64_t)B.t);                                            
  }

  std::string getDateStr() {
    std::string str;
    char datum[40];
    uint64_t tAux = this.t / 1000000000ULL;
    strftime(datum, sizeof(datum), "%Y-%m-%d %H:%M:%S", gmtime((time_t*)&tAux));
    str.append(datum);
    return str;
  }

  std::string getHexStr() {
    return string_format("0x%08x%08x ns", (unsigned)(this.t >> 32), (unsigned)(this.t));
  }

  std::string getDateMsUsNsRemainderStr() {
    uint64_t ts = this.t, ms, us, ns;
         (unsigned)truncateToMultiple(ts, 1000000000ULL); //subtract full seconds
    ms = (unsigned)truncateToMultiple(ts, 1000000ULL);    //save and subtract miliseconds 
    us = (unsigned)truncateToMultiple(ts, 1000ULL);       //save and subtract microseconds 
    ns = (unsigned)ts;                                    //save nanoseconds

    return string_format("%03u ms %03u us %03u ns", ms, us, ns);
  }

  std::string getDiffStr(const NsTime &B) {
    return getDiffStr(this.t - B.t);
  }

  std::string getDiffStr(int64_t d) {
    char sign = (d < 0 ? "-" : " ");
    uint64_t ts = (uint64_t)abs(d), days, hrs, min, s, ms, us, ns;
    days  = (unsigned)truncateToMultiple(ts, 24*60*60*1000000000ULL); //save and subtract days
    hrs   = (unsigned)truncateToMultiple(ts, 60*60*1000000000ULL);    //save and subtract hrs
    min   = (unsigned)truncateToMultiple(ts, 60*1000000000ULL);       //save and subtract min
    s     = (unsigned)truncateToMultiple(ts, 1000000000ULL);          //save and subtract full seconds
    ms    = (unsigned)truncateToMultiple(ts, 1000000ULL);             //save and subtract miliseconds 
    us    = (unsigned)truncateToMultiple(ts, 1000ULL);                //save and subtract microseconds 
    ns    = (unsigned)ts;                                             //save nanoseconds

    return string_format("%c %03u days %02u hrs %02u mins %02u s %03u ms %03u us %03u ns", sign, days, hrs, min, s, ms, us, ns);
  }

  


}





