Require Import Coqlib Integers AST Maps.
Require Import Asm TransSegAsm Segment.
Require Import Errors.
Require Import SegAsmBuiltin.
Require Import Memtype.
Require Import SegAsmProgram.
Import ListNotations.

Local Open Scope error_monad_scope.

Section WITH_GID_MAP.

Variable gmap: GID_MAP_TYPE.

Definition transl_addrmode (a:addrmode) : option addrmode' :=
  let '(Addrmode base ofs const) := a in
  match const with
  | inl z => Some (Addrmode' base ofs (inl z))
  | inr (id, ofs') => 
    match (gmap id) with
    | None => None
    | Some slbl => Some (Addrmode' base ofs (inr slbl))
    end
  end.

Definition transl_instr_addrmode (a:addrmode) (i: Asm.instruction) 
           (cstr: addrmode' -> instruction) :=
  match transl_addrmode a with
  | None => SAsminstr i
  | Some a' => cstr a'
  end.

Definition transl_instr (i: Asm.instruction) : instruction :=
  match i with
  | Pmov_rs rd s =>
    match (gmap s) with
    | None => SAsminstr i
    | Some slbl => Smov_rs rd slbl
    end
  | Pmovl_rm rd a =>
    transl_instr_addrmode a i (fun a' => Smovl_rm rd a')
  | Pmovl_mr a r1 =>
    transl_instr_addrmode a i (fun a' => Smovl_mr a' r1)
  | Pleal rd a =>
    transl_instr_addrmode a i (fun a' => Sleal rd a')
  | Pmov_rm_a rd a =>
    transl_instr_addrmode a i (fun a' => Smov_rm_a rd a')
  | Pmov_mr_a a r1 =>
    transl_instr_addrmode a i (fun a' => Smov_mr_a a' r1)
  | _ => SAsminstr i
  end.

Definition transl_instr' (i: instruction) : instruction :=
  match i with
  | SAsminstr i' => transl_instr i'
  | _ => i
  end.

(** Tranlsation of an instruction *)
Definition transl_instr'' (ii: instr_with_info) : instr_with_info :=
  let '(i, sb, id) := ii in
  (transl_instr' i, sb, id).

(** Translation of a sequence of instructions in a function *)
Fixpoint transl_instrs (instrs: list instr_with_info) : list instr_with_info :=
  List.map transl_instr'' instrs.


(** Tranlsation of a function *)
Definition transl_fun (f:function) : function :=
  let code' := transl_instrs (fn_code f) in
  mkfunction (fn_sig f) code' (fn_range f) 
             (fn_actual_size f) (fn_stacksize f) (fn_pubrange f).

Definition transl_globdef (def: (ident * option TransSegAsm.gdef * segblock)) 
  : (ident * option TransSegAsm.gdef * segblock) :=
  let '(id,def,sb) := def in
  match def with
  | Some (AST.Gfun (Internal f)) =>
    let f' := transl_fun f in
    (id, Some (AST.Gfun (Internal f')), sb)
  | Some (AST.Gfun (External f)) => 
    (id, Some (AST.Gfun (External f)), sb)
  | Some (AST.Gvar v) =>
    (id, Some (AST.Gvar v), sb)
  | None => (id, None, sb)
  end.
    

Fixpoint transl_globdefs defs :=
  List.map transl_globdef defs.

End WITH_GID_MAP.


(** Translation of a program *)
Definition transf_program (p:program) : program := 
  let defs := transl_globdefs (glob_map p) (prog_defs p) in
  (Build_program
        defs
        (prog_public p)
        (prog_main p)
        (data_seg p)
        (code_seg p)
        (glob_map p)
        (lbl_map p)
        (prog_senv p))
      .