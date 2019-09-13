(* *******************  *)
(* Author: Yuting Wang  *)
(* Date:   Sep 13, 2019 *)
(* *******************  *)

(** * Assembly language with information about symbols and relocation *)

Require Import Coqlib Maps Integers Values AST.
Require Import Globalenvs.

(** ** Sections *)
Inductive sectype : Type := SecText | SecData.

Record section : Type :=
{
  sec_type: sectype;
  sec_size: Z;
}.

Definition sectable := PTree.t section.

Definition seclabel : Type := ident * Z.

Record secblock:Type := 
{
  secblock_id: ident;
  secblock_start : Z;  (**r The begining of the block relative to the starting point of the segment *)
  secblock_size : Z;
}.

Definition segblock_to_label (sb: secblock) : seclabel :=
  (secblock_id sb,  secblock_start sb).


(** ** Symbol table *)
Inductive symbtype : Type := SymbFunc | SymbData.

Inductive secindex : Type :=
| secindex_normal (id:ident)
| secindex_comm
| secindex_undef.

Record symbentry : Type :=
{
  symbentry_type: symbtype;
  symbentry_value: Z;  (** This holds the alignment info if secidx is secindex_comm,
                           otherwise, it holds the offset from the beginning of the section *)
  symbentry_secidx: secindex;
}.

Definition symbtable := PTree.t symbentry.


(** ** Relocation table *)
Inductive reloctype : Type := RelocAbs | RelocRel.

Record relocentry : Type :=
{
  reloc_offset: Z;
  reloc_type  : reloctype;
  reloc_symb  : ident;    (* Index into the symbol table *)
  reloc_addend : Z;
}.

Definition reloctable := list relocentry.


(** ** Definition of program constructs *)
Module Type RelocAsmParams.
  Parameter (I D: Type).
End RelocAsmParams.


Module RelocAsmProg (P: RelocAsmParams).

Import P.

Definition instr_with_info:Type := I * secblock * ident.

Definition code := list instr_with_info.
Record function : Type := mkfunction { fn_sig: signature; fn_code: code; fn_range:secblock; fn_actual_size: Z; fn_stacksize: Z; fn_pubrange: Z * Z}.
Definition fundef := AST.fundef function.
Definition gdef := globdef fundef D.

Record program : Type := {
  prog_defs: list (ident * option gdef * secblock);
  prog_public: list ident;
  prog_main: ident;
  prog_symbtable: symbtable;
  prog_reloctable: reloctable;
  prog_senv : Globalenvs.Senv.t;
}.

End RelocAsmProg.