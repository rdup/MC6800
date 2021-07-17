//
//
//	usim.h
//
//	(C) R.P.Bellis 1993
//
//

#ifndef __usim_h__
#define __usim_h__

typedef unsigned char Byte;
typedef unsigned short Word;
typedef unsigned long DWord;

inline int btst(DWord x, int n) { return (x & (1 << n)) ? 1 : 0; }
inline void bset(DWord& x, int n) { x |= (1 << n); }
inline void bclr(DWord& x, int n) { x &= ~(1 << n); }

inline int btst(Word x, int n) { return (x & (1 << n)) ? 1 : 0; }
inline void bset(Word& x, int n) { x |= (1 << n); }
inline void bclr(Word& x, int n) { x &= ~(1 << n); }

inline int btst(Byte x, int n) { return (x & (1 << n)) ? 1 : 0; }
inline void bset(Byte& x, int n) { x |= (1 << n); }
inline void bclr(Byte& x, int n) { x &= ~(1 << n); }

#endif // __usim_h__
