Require Import Coqlib Integers AST Maps.
Require Import Events.
Require Import Asm.
Require Import Errors.
Require Import Memtype.
Require Import Globalenvs .
Import ListNotations.

Local Open Scope error_monad_scope.

Fixpoint findAllLabel (l: list label)(all:list instruction): res (list Z) :=
  match l with
  |[] => OK []
  |h :: t =>
   match label_pos h 0 all with
   |None => Error (msg"Label not found")
   |Some pos =>
    do tail <-  (findAllLabel t all);
      OK (pos::tail)
   end
  end.

Fixpoint eliminate_local_label_aux (c:list instruction) (currentOfs : Z) (all:list instruction) : res (list instruction):=
  match c with
  |[] => OK []
  |h::tail =>     
   let sz := instr_size h in
   match h with
   |Pjmp_l lbl =>
    match label_pos lbl 0 all with
    (* label not found *)
    |None =>   Error (msg"Label not found")
    |Some pos =>
     let relOfs := currentOfs + sz - pos in
     do t <- (eliminate_local_label_aux tail (currentOfs+sz) all);
       OK ((Pjmp_l_rel relOfs) :: t)
    end

   |Pjcc cond lbl =>
    match label_pos lbl 0 all with
    (* label not found *)
    |None =>  Error (msg"Label not found")
    |Some pos =>
     let relOfs := currentOfs + sz - pos in
     do t <- (eliminate_local_label_aux tail (currentOfs+sz) all);
       OK ((Pjcc_rel cond relOfs) :: t)         
    end

   |Pjcc2 cond1 cond2 lbl =>
    match label_pos lbl 0 all with
    (* label not found *)
    |None =>  Error (msg"Label not found")
    |Some pos =>
     let relOfs := currentOfs + sz - pos in
     do t <- (eliminate_local_label_aux tail (currentOfs+sz) all);
       OK ((Pjcc2_rel cond1 cond2 relOfs) :: t)
    end

   |Pjmptbl r tbl =>
    do lst <-  findAllLabel tbl all;
      let ofsLst := map (Zminus (sz + currentOfs)) lst in
      do t <-  (eliminate_local_label_aux tail (currentOfs+sz) all);
        OK ((Pjmptbl_rel r ofsLst) :: t)
           
   |_ =>
    do t <- (eliminate_local_label_aux tail (currentOfs+sz) all);
      OK (h :: t)
   end
  end.

Definition trans_function (f: function) :res function :=
  if func_no_jmp_rel_dec f then 
    do instrs <- (eliminate_local_label_aux (fn_code f) 0 (fn_code f));
      OK (mkfunction (fn_sig f) instrs (fn_stacksize f) (fn_pubrange f))
  else
    Error (msg "Some source function contains relative jumps").

Definition transf_fundef (f: Asm.fundef) : res Asm.fundef :=
  transf_partial_fundef trans_function f.

Definition transf_program (p: Asm.program) : res Asm.program :=
  transform_partial_program transf_fundef p.


