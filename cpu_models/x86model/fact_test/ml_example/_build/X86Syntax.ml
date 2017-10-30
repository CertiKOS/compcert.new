open Bits

(** val sign_extend : Big.big_int -> Big.big_int -> Word.int -> Word.int **)

let sign_extend n1 n2 w =
  Word.repr n2 (Word.signed n1 w)

(** val zero_extend8_32 : Word.int -> Word.int **)

let zero_extend8_32 w =
  Word.repr (Big.succ (Big.succ (Big.succ (Big.succ (Big.succ (Big.succ
    (Big.succ (Big.succ (Big.succ (Big.succ (Big.succ (Big.succ (Big.succ
    (Big.succ (Big.succ (Big.succ (Big.succ (Big.succ (Big.succ (Big.succ
    (Big.succ (Big.succ (Big.succ (Big.succ (Big.succ (Big.succ (Big.succ
    (Big.succ (Big.succ (Big.succ (Big.succ
    Big.zero))))))))))))))))))))))))))))))) w

(** val sign_extend8_32 : Word.int -> Word.int **)

let sign_extend8_32 =
  sign_extend (Big.succ (Big.succ (Big.succ (Big.succ (Big.succ (Big.succ
    (Big.succ Big.zero))))))) (Big.succ (Big.succ (Big.succ (Big.succ
    (Big.succ (Big.succ (Big.succ (Big.succ (Big.succ (Big.succ (Big.succ
    (Big.succ (Big.succ (Big.succ (Big.succ (Big.succ (Big.succ (Big.succ
    (Big.succ (Big.succ (Big.succ (Big.succ (Big.succ (Big.succ (Big.succ
    (Big.succ (Big.succ (Big.succ (Big.succ (Big.succ (Big.succ
    Big.zero)))))))))))))))))))))))))))))))

(** val sign_extend16_32 : Word.int -> Word.int **)

let sign_extend16_32 =
  sign_extend (Big.succ (Big.succ (Big.succ (Big.succ (Big.succ (Big.succ
    (Big.succ (Big.succ (Big.succ (Big.succ (Big.succ (Big.succ (Big.succ
    (Big.succ (Big.succ Big.zero))))))))))))))) (Big.succ (Big.succ (Big.succ
    (Big.succ (Big.succ (Big.succ (Big.succ (Big.succ (Big.succ (Big.succ
    (Big.succ (Big.succ (Big.succ (Big.succ (Big.succ (Big.succ (Big.succ
    (Big.succ (Big.succ (Big.succ (Big.succ (Big.succ (Big.succ (Big.succ
    (Big.succ (Big.succ (Big.succ (Big.succ (Big.succ (Big.succ (Big.succ
    Big.zero)))))))))))))))))))))))))))))))

type port_number = int8

type interrupt_type = int8

type selector = int16

type register =
| EAX
| ECX
| EDX
| EBX
| ESP
| EBP
| ESI
| EDI

(** val register_eq_dec : register -> register -> bool **)

let register_eq_dec x y =
  match x with
  | EAX ->
    (match y with
     | EAX -> true
     | _ -> false)
  | ECX ->
    (match y with
     | ECX -> true
     | _ -> false)
  | EDX ->
    (match y with
     | EDX -> true
     | _ -> false)
  | EBX ->
    (match y with
     | EBX -> true
     | _ -> false)
  | ESP ->
    (match y with
     | ESP -> true
     | _ -> false)
  | EBP ->
    (match y with
     | EBP -> true
     | _ -> false)
  | ESI ->
    (match y with
     | ESI -> true
     | _ -> false)
  | EDI ->
    (match y with
     | EDI -> true
     | _ -> false)

(** val coq_Z_to_register : Big.big_int -> register **)

let coq_Z_to_register n =
  Big.z_case
    (fun _ ->
    EAX)
    (fun p ->
    Big.positive_case
      (fun p0 ->
      Big.positive_case
        (fun _ ->
        EDI)
        (fun p1 ->
        Big.positive_case
          (fun _ ->
          EDI)
          (fun _ ->
          EDI)
          (fun _ ->
          EBP)
          p1)
        (fun _ ->
        EBX)
        p0)
      (fun p0 ->
      Big.positive_case
        (fun p1 ->
        Big.positive_case
          (fun _ ->
          EDI)
          (fun _ ->
          EDI)
          (fun _ ->
          ESI)
          p1)
        (fun p1 ->
        Big.positive_case
          (fun _ ->
          EDI)
          (fun _ ->
          EDI)
          (fun _ ->
          ESP)
          p1)
        (fun _ ->
        EDX)
        p0)
      (fun _ ->
      ECX)
      p)
    (fun _ ->
    EDI)
    n

type scale =
| Scale1
| Scale2
| Scale4
| Scale8

(** val coq_Z_to_scale : Big.big_int -> scale **)

let coq_Z_to_scale n =
  Big.z_case
    (fun _ ->
    Scale1)
    (fun p ->
    Big.positive_case
      (fun _ ->
      Scale8)
      (fun p0 ->
      Big.positive_case
        (fun _ ->
        Scale8)
        (fun _ ->
        Scale8)
        (fun _ ->
        Scale4)
        p0)
      (fun _ ->
      Scale2)
      p)
    (fun _ ->
    Scale8)
    n

type segment_register =
| ES
| CS
| SS
| DS
| FS
| GS

(** val segment_register_eq_dec :
    segment_register -> segment_register -> bool **)

let segment_register_eq_dec x y =
  match x with
  | ES ->
    (match y with
     | ES -> true
     | _ -> false)
  | CS ->
    (match y with
     | CS -> true
     | _ -> false)
  | SS ->
    (match y with
     | SS -> true
     | _ -> false)
  | DS ->
    (match y with
     | DS -> true
     | _ -> false)
  | FS ->
    (match y with
     | FS -> true
     | _ -> false)
  | GS ->
    (match y with
     | GS -> true
     | _ -> false)

type control_register =
| CR0
| CR2
| CR3
| CR4

(** val control_register_eq_dec :
    control_register -> control_register -> bool **)

let control_register_eq_dec x y =
  match x with
  | CR0 ->
    (match y with
     | CR0 -> true
     | _ -> false)
  | CR2 ->
    (match y with
     | CR2 -> true
     | _ -> false)
  | CR3 ->
    (match y with
     | CR3 -> true
     | _ -> false)
  | CR4 ->
    (match y with
     | CR4 -> true
     | _ -> false)

type debug_register =
| DR0
| DR1
| DR2
| DR3
| DR6
| DR7

(** val debug_register_eq_dec : debug_register -> debug_register -> bool **)

let debug_register_eq_dec x y =
  match x with
  | DR0 ->
    (match y with
     | DR0 -> true
     | _ -> false)
  | DR1 ->
    (match y with
     | DR1 -> true
     | _ -> false)
  | DR2 ->
    (match y with
     | DR2 -> true
     | _ -> false)
  | DR3 ->
    (match y with
     | DR3 -> true
     | _ -> false)
  | DR6 ->
    (match y with
     | DR6 -> true
     | _ -> false)
  | DR7 ->
    (match y with
     | DR7 -> true
     | _ -> false)

type address = { addrDisp : int32; addrBase : register option;
                 addrIndex : (scale * register) option }

(** val addrDisp : address -> int32 **)

let addrDisp x = x.addrDisp

(** val addrBase : address -> register option **)

let addrBase x = x.addrBase

(** val addrIndex : address -> (scale * register) option **)

let addrIndex x = x.addrIndex

type operand =
| Imm_op of int32
| Reg_op of register
| Address_op of address
| Offset_op of int32

type reg_or_immed =
| Reg_ri of register
| Imm_ri of int8

type condition_type =
| O_ct
| NO_ct
| B_ct
| NB_ct
| E_ct
| NE_ct
| BE_ct
| NBE_ct
| S_ct
| NS_ct
| P_ct
| NP_ct
| L_ct
| NL_ct
| LE_ct
| NLE_ct

(** val coq_Z_to_condition_type : Big.big_int -> condition_type **)

let coq_Z_to_condition_type n =
  Big.z_case
    (fun _ ->
    O_ct)
    (fun p ->
    Big.positive_case
      (fun p0 ->
      Big.positive_case
        (fun p1 ->
        Big.positive_case
          (fun _ ->
          NLE_ct)
          (fun p2 ->
          Big.positive_case
            (fun _ ->
            NLE_ct)
            (fun _ ->
            NLE_ct)
            (fun _ ->
            NP_ct)
            p2)
          (fun _ ->
          NBE_ct)
          p1)
        (fun p1 ->
        Big.positive_case
          (fun p2 ->
          Big.positive_case
            (fun _ ->
            NLE_ct)
            (fun _ ->
            NLE_ct)
            (fun _ ->
            NL_ct)
            p2)
          (fun p2 ->
          Big.positive_case
            (fun _ ->
            NLE_ct)
            (fun _ ->
            NLE_ct)
            (fun _ ->
            NS_ct)
            p2)
          (fun _ ->
          NE_ct)
          p1)
        (fun _ ->
        NB_ct)
        p0)
      (fun p0 ->
      Big.positive_case
        (fun p1 ->
        Big.positive_case
          (fun p2 ->
          Big.positive_case
            (fun _ ->
            NLE_ct)
            (fun _ ->
            NLE_ct)
            (fun _ ->
            LE_ct)
            p2)
          (fun p2 ->
          Big.positive_case
            (fun _ ->
            NLE_ct)
            (fun _ ->
            NLE_ct)
            (fun _ ->
            P_ct)
            p2)
          (fun _ ->
          BE_ct)
          p1)
        (fun p1 ->
        Big.positive_case
          (fun p2 ->
          Big.positive_case
            (fun _ ->
            NLE_ct)
            (fun _ ->
            NLE_ct)
            (fun _ ->
            L_ct)
            p2)
          (fun p2 ->
          Big.positive_case
            (fun _ ->
            NLE_ct)
            (fun _ ->
            NLE_ct)
            (fun _ ->
            S_ct)
            p2)
          (fun _ ->
          E_ct)
          p1)
        (fun _ ->
        B_ct)
        p0)
      (fun _ ->
      NO_ct)
      p)
    (fun _ ->
    NLE_ct)
    n

type fp_operand =
| FPS_op of int3
| FPM16_op of address
| FPM32_op of address
| FPM64_op of address
| FPM80_op of address

type fp_condition_type =
| B_fct
| E_fct
| BE_fct
| U_fct
| NB_fct
| NE_fct
| NBE_fct
| NU_fct

(** val coq_Z_to_fp_condition_type : Big.big_int -> fp_condition_type **)

let coq_Z_to_fp_condition_type n =
  Big.z_case
    (fun _ ->
    B_fct)
    (fun p ->
    Big.positive_case
      (fun p0 ->
      Big.positive_case
        (fun _ ->
        NU_fct)
        (fun p1 ->
        Big.positive_case
          (fun _ ->
          NU_fct)
          (fun _ ->
          NU_fct)
          (fun _ ->
          NE_fct)
          p1)
        (fun _ ->
        U_fct)
        p0)
      (fun p0 ->
      Big.positive_case
        (fun p1 ->
        Big.positive_case
          (fun _ ->
          NU_fct)
          (fun _ ->
          NU_fct)
          (fun _ ->
          NBE_fct)
          p1)
        (fun p1 ->
        Big.positive_case
          (fun _ ->
          NU_fct)
          (fun _ ->
          NU_fct)
          (fun _ ->
          NB_fct)
          p1)
        (fun _ ->
        BE_fct)
        p0)
      (fun _ ->
      E_fct)
      p)
    (fun _ ->
    NU_fct)
    n

type mmx_register = int3

type mmx_granularity =
| MMX_8
| MMX_16
| MMX_32
| MMX_64

type mmx_operand =
| GP_Reg_op of register
| MMX_Addr_op of address
| MMX_Reg_op of mmx_register
| MMX_Imm_op of int32

type sse_register = int3

type sse_operand =
| SSE_XMM_Reg_op of sse_register
| SSE_MM_Reg_op of mmx_register
| SSE_Addr_op of address
| SSE_GP_Reg_op of register
| SSE_Imm_op of int32

type instr =
| AAA
| AAD
| AAM
| AAS
| ADC of bool * operand * operand
| ADD of bool * operand * operand
| AND of bool * operand * operand
| ARPL of operand * operand
| BOUND of operand * operand
| BSF of operand * operand
| BSR of operand * operand
| BSWAP of register
| BT of operand * operand
| BTC of operand * operand
| BTR of operand * operand
| BTS of operand * operand
| CALL of bool * bool * operand * selector option
| CDQ
| CLC
| CLD
| CLI
| CLTS
| CMC
| CMOVcc of condition_type * operand * operand
| CMP of bool * operand * operand
| CMPS of bool
| CMPXCHG of bool * operand * operand
| CPUID
| CWDE
| DAA
| DAS
| DEC of bool * operand
| DIV of bool * operand
| F2XM1
| FABS
| FADD of bool * fp_operand
| FADDP of fp_operand
| FBLD of fp_operand
| FBSTP of fp_operand
| FCHS
| FCMOVcc of fp_condition_type * fp_operand
| FCOM of fp_operand
| FCOMP of fp_operand
| FCOMPP
| FCOMIP of fp_operand
| FCOS
| FDECSTP
| FDIV of bool * fp_operand
| FDIVP of fp_operand
| FDIVR of bool * fp_operand
| FDIVRP of fp_operand
| FFREE of fp_operand
| FIADD of fp_operand
| FICOM of fp_operand
| FICOMP of fp_operand
| FIDIV of fp_operand
| FIDIVR of fp_operand
| FILD of fp_operand
| FIMUL of fp_operand
| FINCSTP
| FIST of fp_operand
| FISTP of fp_operand
| FISUB of fp_operand
| FISUBR of fp_operand
| FLD of fp_operand
| FLD1
| FLDCW of fp_operand
| FLDENV of fp_operand
| FLDL2E
| FLDL2T
| FLDLG2
| FLDLN2
| FLDPI
| FLDZ
| FMUL of bool * fp_operand
| FMULP of fp_operand
| FNCLEX
| FNINIT
| FNOP
| FNSAVE of fp_operand
| FNSTCW of fp_operand
| FNSTSW of fp_operand option
| FPATAN
| FPREM
| FPREM1
| FPTAN
| FRNDINT
| FRSTOR of fp_operand
| FSCALE
| FSIN
| FSINCOS
| FSQRT
| FST of fp_operand
| FSTENV of fp_operand
| FSTP of fp_operand
| FSUB of bool * fp_operand
| FSUBP of fp_operand
| FSUBR of bool * fp_operand
| FSUBRP of fp_operand
| FTST
| FUCOM of fp_operand
| FUCOMP of fp_operand
| FUCOMPP
| FUCOMI of fp_operand
| FUCOMIP of fp_operand
| FXAM
| FXCH of fp_operand
| FXTRACT
| FYL2X
| FYL2XP1
| FWAIT
| EMMS
| MOVD of mmx_operand * mmx_operand
| MOVQ of mmx_operand * mmx_operand
| PACKSSDW of mmx_operand * mmx_operand
| PACKSSWB of mmx_operand * mmx_operand
| PACKUSWB of mmx_operand * mmx_operand
| PADD of mmx_granularity * mmx_operand * mmx_operand
| PADDS of mmx_granularity * mmx_operand * mmx_operand
| PADDUS of mmx_granularity * mmx_operand * mmx_operand
| PAND of mmx_operand * mmx_operand
| PANDN of mmx_operand * mmx_operand
| PCMPEQ of mmx_granularity * mmx_operand * mmx_operand
| PCMPGT of mmx_granularity * mmx_operand * mmx_operand
| PMADDWD of mmx_operand * mmx_operand
| PMULHUW of mmx_operand * mmx_operand
| PMULHW of mmx_operand * mmx_operand
| PMULLW of mmx_operand * mmx_operand
| POR of mmx_operand * mmx_operand
| PSLL of mmx_granularity * mmx_operand * mmx_operand
| PSRA of mmx_granularity * mmx_operand * mmx_operand
| PSRL of mmx_granularity * mmx_operand * mmx_operand
| PSUB of mmx_granularity * mmx_operand * mmx_operand
| PSUBS of mmx_granularity * mmx_operand * mmx_operand
| PSUBUS of mmx_granularity * mmx_operand * mmx_operand
| PUNPCKH of mmx_granularity * mmx_operand * mmx_operand
| PUNPCKL of mmx_granularity * mmx_operand * mmx_operand
| PXOR of mmx_operand * mmx_operand
| ADDPS of sse_operand * sse_operand
| ADDSS of sse_operand * sse_operand
| ANDNPS of sse_operand * sse_operand
| ANDPS of sse_operand * sse_operand
| CMPPS of sse_operand * sse_operand * int8
| CMPSS of sse_operand * sse_operand * int8
| COMISS of sse_operand * sse_operand
| CVTPI2PS of sse_operand * sse_operand
| CVTPS2PI of sse_operand * sse_operand
| CVTSI2SS of sse_operand * sse_operand
| CVTSS2SI of sse_operand * sse_operand
| CVTTPS2PI of sse_operand * sse_operand
| CVTTSS2SI of sse_operand * sse_operand
| DIVPS of sse_operand * sse_operand
| DIVSS of sse_operand * sse_operand
| LDMXCSR of sse_operand
| MAXPS of sse_operand * sse_operand
| MAXSS of sse_operand * sse_operand
| MINPS of sse_operand * sse_operand
| MINSS of sse_operand * sse_operand
| MOVAPS of sse_operand * sse_operand
| MOVHLPS of sse_operand * sse_operand
| MOVHPS of sse_operand * sse_operand
| MOVLHPS of sse_operand * sse_operand
| MOVLPS of sse_operand * sse_operand
| MOVMSKPS of sse_operand * sse_operand
| MOVSS of sse_operand * sse_operand
| MOVUPS of sse_operand * sse_operand
| MULPS of sse_operand * sse_operand
| MULSS of sse_operand * sse_operand
| ORPS of sse_operand * sse_operand
| RCPPS of sse_operand * sse_operand
| RCPSS of sse_operand * sse_operand
| RSQRTPS of sse_operand * sse_operand
| RSQRTSS of sse_operand * sse_operand
| SHUFPS of sse_operand * sse_operand * int8
| SQRTPS of sse_operand * sse_operand
| SQRTSS of sse_operand * sse_operand
| STMXCSR of sse_operand
| SUBPS of sse_operand * sse_operand
| SUBSS of sse_operand * sse_operand
| UCOMISS of sse_operand * sse_operand
| UNPCKHPS of sse_operand * sse_operand
| UNPCKLPS of sse_operand * sse_operand
| XORPS of sse_operand * sse_operand
| PAVGB of sse_operand * sse_operand
| PEXTRW of sse_operand * sse_operand * int8
| PINSRW of sse_operand * sse_operand * int8
| PMAXSW of sse_operand * sse_operand
| PMAXUB of sse_operand * sse_operand
| PMINSW of sse_operand * sse_operand
| PMINUB of sse_operand * sse_operand
| PMOVMSKB of sse_operand * sse_operand
| PSADBW of sse_operand * sse_operand
| PSHUFW of sse_operand * sse_operand * int8
| MASKMOVQ of sse_operand * sse_operand
| MOVNTPS of sse_operand * sse_operand
| MOVNTQ of sse_operand * sse_operand
| PREFETCHT0 of sse_operand
| PREFETCHT1 of sse_operand
| PREFETCHT2 of sse_operand
| PREFETCHNTA of sse_operand
| SFENCE
| HLT
| IDIV of bool * operand
| IMUL of bool * operand * operand option * int32 option
| IN of bool * port_number option
| INC of bool * operand
| INS of bool
| INTn of interrupt_type
| INT
| INTO
| INVD
| INVLPG of operand
| IRET
| Jcc of condition_type * int32
| JCXZ of int8
| JMP of bool * bool * operand * selector option
| LAHF
| LAR of operand * operand
| LDS of operand * operand
| LEA of operand * operand
| LEAVE
| LES of operand * operand
| LFS of operand * operand
| LGDT of operand
| LGS of operand * operand
| LIDT of operand
| LLDT of operand
| LMSW of operand
| LODS of bool
| LOOP of int8
| LOOPZ of int8
| LOOPNZ of int8
| LSL of operand * operand
| LSS of operand * operand
| LTR of operand
| MOV of bool * operand * operand
| MOVCR of bool * control_register * register
| MOVDR of bool * debug_register * register
| MOVSR of bool * segment_register * operand
| MOVBE of operand * operand
| MOVS of bool
| MOVSX of bool * operand * operand
| MOVZX of bool * operand * operand
| MUL of bool * operand
| NEG of bool * operand
| NOP of operand
| NOT of bool * operand
| OR of bool * operand * operand
| OUT of bool * port_number option
| OUTS of bool
| POP of operand
| POPSR of segment_register
| POPA
| POPF
| PUSH of bool * operand
| PUSHSR of segment_register
| PUSHA
| PUSHF
| RCL of bool * operand * reg_or_immed
| RCR of bool * operand * reg_or_immed
| RDMSR
| RDPMC
| RDTSC
| RDTSCP
| RET of bool * int16 option
| ROL of bool * operand * reg_or_immed
| ROR of bool * operand * reg_or_immed
| RSM
| SAHF
| SAR of bool * operand * reg_or_immed
| SBB of bool * operand * operand
| SCAS of bool
| SETcc of condition_type * operand
| SGDT of operand
| SHL of bool * operand * reg_or_immed
| SHLD of operand * register * reg_or_immed
| SHR of bool * operand * reg_or_immed
| SHRD of operand * register * reg_or_immed
| SIDT of operand
| SLDT of operand
| SMSW of operand
| STC
| STD
| STI
| STOS of bool
| STR of operand
| SUB of bool * operand * operand
| TEST of bool * operand * operand
| UD2
| VERR of operand
| VERW of operand
| WBINVD
| WRMSR
| XADD of bool * operand * operand
| XCHG of bool * operand * operand
| XLAT
| XOR of bool * operand * operand

type lock_or_rep =
| Coq_lock
| Coq_rep
| Coq_repn

type prefix = { lock_rep : lock_or_rep option;
                seg_override : segment_register option; op_override : 
                bool; addr_override : bool }

(** val lock_rep : prefix -> lock_or_rep option **)

let lock_rep x = x.lock_rep

(** val seg_override : prefix -> segment_register option **)

let seg_override x = x.seg_override

(** val op_override : prefix -> bool **)

let op_override x = x.op_override

(** val addr_override : prefix -> bool **)

let addr_override x = x.addr_override
