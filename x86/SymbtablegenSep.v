Require Import Coqlib Integers AST Maps.
Require Import Asm.
Require Import Errors.
Require Import Memtype.
Require Import Asm RelocProgram.
Require Import Symbtablegen.
Require Import Linking RelocLinking.
Require Import SeqTable.
Import ListNotations.

Set Implicit Arguments.

Definition match_prog (p: Asm.program) (tp: program) :=
  transf_program p = OK tp.

Lemma link_prog_inv: forall (F V: Type) (fi:F -> bool) (LF: Linker F) (LV: Linker V) (p1 p2 p: AST.program F V), 
    link_prog fi p1 p2 = Some p ->
    (AST.prog_main p1 = AST.prog_main p2)
    /\ list_norepet (map fst (AST.prog_defs p1))
    /\ list_norepet (map fst (AST.prog_defs p2))
    /\ exists defs, 
        p = {| AST.prog_defs := defs; 
               AST.prog_public := AST.prog_public p1 ++ AST.prog_public p2; 
               AST.prog_main := AST.prog_main p1 |}
        /\ link_defs fi (AST.prog_defs p1) (AST.prog_defs p2) = Some defs.
Proof.
  intros F V fi LF LV p1 p2 p LINK.
  unfold link_prog in LINK.
  destruct ident_eq; simpl in LINK.
  unfold prog_unique_idents in LINK.
  repeat (destruct list_norepet_dec; simpl in LINK).
  destr_in LINK; inv LINK. 
  repeat split; auto. eauto.
  congruence.
  congruence.
  congruence.
Qed.


Lemma match_prog_pres_prog_defs : forall p tp,
  match_prog p tp -> AST.prog_defs p = prog_defs tp.
Proof.
  intros p tp MATCH. red in MATCH.
  unfold transf_program in MATCH.
  destruct check_wellformedness; try monadInv MATCH.
  destruct (gen_symb_table sec_data_id sec_code_id (AST.prog_defs p)) eqn:EQ.
  destruct p0. 
  destruct zle; try monadInv MATCH. simpl. auto.
Qed.

Lemma match_prog_pres_prog_main : forall p tp,
  match_prog p tp -> AST.prog_main p = prog_main tp.
Proof.
  intros p tp MATCH. red in MATCH.
  unfold transf_program in MATCH.
  destruct check_wellformedness; try monadInv MATCH.
  destruct (gen_symb_table sec_data_id sec_code_id (AST.prog_defs p)) eqn:EQ.
  destruct p0. 
  destruct zle; try monadInv MATCH. simpl. auto.
Qed.

Lemma match_prog_pres_prog_public : forall p tp,
  match_prog p tp -> AST.prog_public p = prog_public tp.
Proof.
  intros p tp MATCH. red in MATCH.
  unfold transf_program in MATCH.
  destruct check_wellformedness; try monadInv MATCH.
  destruct (gen_symb_table sec_data_id sec_code_id (AST.prog_defs p)) eqn:EQ.
  destruct p0. 
  destruct zle; try monadInv MATCH. simpl. auto.
Qed.

(* Lemma link_defs_acc_symb_comm : forall defs1 defs2 defs rstbl1 dsz1 csz1 rstbl2 dsz2 csz2, *)
(*       link_defs_aux is_fundef_internal defs1 defs2 postponed = Some defs -> *)
(*       fold_left (acc_symb sec_data_id sec_code_id) defs1 (entries1', dsz1', csz1') = (entries1 ++ entries1', dsz1, csz1) -> *)
(*       fold_left (acc_symb sec_data_id sec_code_id) defs2 (entries2', dsz2', csz2') = (entries2 ++ entries2', dsz2, csz2) -> *)
(*       exists stbl,  *)
(*         link_symbtable_aux (reloc_offset_fun' dsz1 csz1) *)
(*                            (rev entries1) *)
(*                            (rev entries2) *)
(*                             = Some stbl /\ *)
(*         fold_left (acc_symb sec_data_id sec_code_id) defs ([dummy_symbentry], 0, 0) =  *)
(*         (rev stbl, dsz1 + dsz2, csz1 + csz2). *)
(* Proof. *)
(*   intros defs1 defs2 defs rstbl1 dsz1 csz1 rstbl2 dsz2 csz2 LINK ACC1 ACC2. *)
(*   unfold link_symbtable. *)


(* Lemma link_defs_acc_symb_comm : forall defs1 defs2 defs rstbl1 dsz1 csz1 rstbl2 dsz2 csz2, *)
(*       link_defs_aux is_fundef_internal defs1 defs2 [] = Some defs -> *)
(*       fold_left (acc_symb sec_data_id sec_code_id) defs1 ([dummy_symbentry], 0, 0) = (rstbl1, dsz1, csz1) -> *)
(*       fold_left (acc_symb sec_data_id sec_code_id) defs2 ([dummy_symbentry], 0, 0) = (rstbl2, dsz2, csz2) -> *)
(*       exists stbl,  *)
(*         link_symbtable (reloc_offset_fun (create_data_section defs1) (create_code_section defs1))  *)
(*                        (rev rstbl1) (rev rstbl2) = Some stbl /\ *)
(*         fold_left (acc_symb sec_data_id sec_code_id) defs ([dummy_symbentry], 0, 0) =  *)
(*         (rev stbl, dsz1 + dsz2, csz1 + csz2). *)
(* Proof. *)
(*   induction defs1 as [| def defs1']. *)
(*   - intros defs2 defs rstbl1 dsz1 csz1 rstbl2 dsz2 csz2 LINK ACC1 ACC2. *)
(*     simpl in *. inv LINK. inv ACC1. *)
(*     simpl. *)
(*     admit. *)
(*   - intros defs2 defs rstbl1 dsz1 csz1 rstbl2 dsz2 csz2 LINK ACC1 ACC2. *)
(*     simpl in *. destruct def as (id1 & def1). *)
(*     destruct (partition (fun '(id', _) => ident_eq id' id1) defs2) as (defs2' & defs2'') eqn:PART. *)
(*     destruct defs2' as [| def2 defs2''']. *)
    

(*   intros defs1 defs2 defs rstbl1 dsz1 csz1 rstbl2 dsz2 csz2  *)
(*   unfold link_symbtable. *)



Definition symbentry_index_in_range range e :=
  match symbentry_secindex e with
  | secindex_normal i => In i range
  | _ => True
  end.

Definition symbtable_indexes_in_range range t :=
  Forall (symbentry_index_in_range range) t.

Lemma gen_symb_table_index_in_range : forall defs sec_data_id sec_code_id stbl dsz csz,
    gen_symb_table sec_data_id sec_code_id defs = (stbl, dsz, csz) ->
    symbtable_indexes_in_range (map SecIndex.interp [sec_data_id; sec_code_id]) stbl.
Admitted.

Lemma reloc_symbtable_exists : forall stbl f dsz csz,
    symbtable_indexes_in_range (map SecIndex.interp [sec_data_id; sec_code_id]) stbl ->
    f = (reloc_offset_fun dsz csz) ->
    exists stbl', reloc_symbtable f stbl = Some stbl' /\
             Forall2 (fun e1 e2 => reloc_symb f e1 = Some e2) stbl stbl'.
Admitted.


Lemma link_gen_symb_comm : forall defs1 defs2 defs stbl1 stbl2 dsz1 csz1 dsz2 csz2 f_ofs,
    link_defs is_fundef_internal defs1 defs2 = Some defs ->
    gen_symb_table sec_data_id sec_code_id defs1 = (stbl1, dsz1, csz1) ->
    gen_symb_table sec_data_id sec_code_id defs2 = (stbl2, dsz2, csz2) ->
    f_ofs = reloc_offset_fun dsz1 csz1 ->
    exists stbl stbl2',
      reloc_symbtable f_ofs stbl2 = Some stbl2' /\
      link_symbtable stbl1 stbl2' = Some stbl
      /\ gen_symb_table sec_data_id sec_code_id defs = (stbl, dsz1 + dsz2, csz1 + csz2).
Proof.
Admitted.
(*   intros defs1 defs2 defs stbl1 stbl2 dsz1 csz1 dsz2 csz2 LINK GS1 GS2. *)
(*   unfold link_defs in LINK. *)
(*   unfold gen_symb_table in GS1, GS2. *)
(*   destruct (fold_left (acc_symb sec_data_id sec_code_id) defs1 ([dummy_symbentry], 0, 0)) *)
(*     as (r1 & csz1') eqn:GSEQ1. destruct r1 as (rstbl1 & dsz1'). inv GS1. *)
(*   destruct (fold_left (acc_symb sec_data_id sec_code_id) defs2 ([dummy_symbentry], 0, 0)) *)
(*     as (r2 & csz') eqn:GSEQ2. destruct r2 as (rstbl2 & dsz2'). inv GS2. *)
(*   unfold gen_symb_table. *)
(*   exploit link_defs_acc_symb_comm; eauto. *)
(*   destruct 1 as (stbl & LINKS & ACC). *)
(*   exists stbl. split; auto. rewrite ACC. *)
(*   rewrite rev_involutive. auto. *)
(* Qed. *)



Lemma link_pres_wf_prog: forall p1 p2 p defs,
    link_defs is_fundef_internal (AST.prog_defs p1) (AST.prog_defs p2) = Some defs ->
    wf_prog p1 -> wf_prog p2 -> 
    p = {| AST.prog_defs := defs; 
           AST.prog_public := AST.prog_public p1 ++ AST.prog_public p2; 
           AST.prog_main := AST.prog_main p1 |} ->
    wf_prog p.
Admitted.

Lemma acc_init_data_app : forall def l1 l2,
    (acc_init_data def l1) ++ l2 = acc_init_data def (l1 ++ l2).
Proof.
  intros def l1 l2. destruct def as (id & def').
  simpl. rewrite app_assoc. auto.
Qed.

Lemma fold_right_acc_init_data_app : forall defs l,
    fold_right acc_init_data [] defs ++ l = fold_right acc_init_data l defs.
Proof.
  induction defs. 
  - intros l. simpl. auto.
  - intros l. simpl. 
    rewrite acc_init_data_app. rewrite IHdefs. auto.
Qed.


Lemma link_acc_init_data_comm : forall defs1 defs2 defs,
    link_defs is_fundef_internal defs1 defs2 = Some defs ->
    fold_right acc_init_data [] defs = fold_right acc_init_data [] (defs1 ++ defs2).
Admitted.


Lemma acc_instrs_app : forall def l1 l2,
    (acc_instrs def l1) ++ l2 = acc_instrs def (l1 ++ l2).
Proof.
  intros def l1 l2. destruct def as (id & def').
  simpl. rewrite app_assoc. auto.
Qed.

Lemma fold_right_acc_instrs_app : forall defs l,
    fold_right acc_instrs [] defs ++ l = fold_right acc_instrs l defs.
Proof.
  induction defs. 
  - intros l. simpl. auto.
  - intros l. simpl. 
    rewrite acc_instrs_app. rewrite IHdefs. auto.
Qed.

Lemma link_acc_instrs_comm : forall defs1 defs2 defs,
    link_defs is_fundef_internal defs1 defs2 = Some defs ->
    fold_right acc_instrs [] defs = fold_right acc_instrs [] (defs1 ++ defs2).
Admitted.


Lemma link_transf_symbtablegen : forall (p1 p2 : Asm.program) (tp1 tp2 : program) (p : Asm.program),
    link p1 p2 = Some p -> match_prog p1 tp1 -> match_prog p2 tp2 -> 
    exists tp : program, link tp1 tp2 = Some tp /\ match_prog p tp.
Proof.
  intros p1 p2 tp1 tp2 p LINK MATCH1 MATCH2.
  unfold link. unfold Linker_reloc_prog. unfold link_reloc_prog.
  rewrite <- (match_prog_pres_prog_defs MATCH1).
  rewrite <- (match_prog_pres_prog_defs MATCH2).
  rewrite <- (match_prog_pres_prog_main MATCH1).
  rewrite <- (match_prog_pres_prog_main MATCH2).
  rewrite <- (match_prog_pres_prog_public MATCH1).
  rewrite <- (match_prog_pres_prog_public MATCH2).
  setoid_rewrite LINK.
  apply link_prog_inv in LINK.
  destruct LINK as (MAINEQ & NRPT1 & NRPT2 & defs & PEQ & LINKDEFS). subst. simpl.
  unfold match_prog in *.

  unfold transf_program in MATCH1.
  destruct check_wellformedness; try monadInv MATCH1.
  destruct (gen_symb_table sec_data_id sec_code_id (AST.prog_defs p1)) as (p & csz1) eqn:GSEQ1 .
  destruct p as (stbl1 & dsz1).
  destruct zle; try monadInv MATCH1; simpl.
  
  unfold transf_program in MATCH2.
  destruct check_wellformedness; try monadInv MATCH2.
  destruct (gen_symb_table sec_data_id sec_code_id (AST.prog_defs p2)) as (p & csz2) eqn:GSEQ2 .
  destruct p as (stbl2 & dsz2).
  destruct zle; try monadInv MATCH2; simpl.
  

  (* generalize (gen_symb_table_index_in_range _ _ _ GSEQ2). *)
  (* intro SIDX_RANGE2.   *)
  (* generalize (reloc_symbtable_exists  *)
  (*               SIDX_RANGE2  *)
  (*               (eq_refl  *)
  (*                  (reloc_offset_fun (sec_size (create_data_section (AST.prog_defs p1))) *)
  (*                                    (sec_size (create_code_section (AST.prog_defs p1)))))). *)
  (* destruct 1 as (stbl2' & RELOC2 & RELOC_REL). *)
  (* setoid_rewrite RELOC2. *)

  exploit link_gen_symb_comm; eauto.
  destruct 1 as (stbl & stbl2' & RELOC & LINKS & GENS).

  Lemma gen_symb_table_size: forall defs d_id c_id stbl dsz csz,
      gen_symb_table d_id c_id defs = (stbl, dsz, csz) ->
      sec_size (create_data_section defs) = dsz /\
      sec_size (create_code_section defs) = csz.
  Admitted.

  generalize (gen_symb_table_size _ _ _ GSEQ1).
  destruct 1 as (DSZ & CSZ).
  setoid_rewrite DSZ.
  setoid_rewrite CSZ.
  rewrite RELOC.
  rewrite LINKS.

  eexists. split. reflexivity.
  unfold transf_program.

  exploit link_pres_wf_prog; eauto.
  intros WF.
  destruct check_wellformedness; try congruence.
  simpl. rewrite GENS.
  
  destruct zle.
  repeat f_equal.
  unfold create_sec_table. repeat f_equal.
  unfold create_data_section. f_equal.
  rewrite fold_right_acc_init_data_app.
  rewrite <- fold_right_app.
  apply link_acc_init_data_comm; auto.
  unfold create_code_section. f_equal.
  rewrite fold_right_acc_instrs_app.
  rewrite <- fold_right_app.
  apply link_acc_instrs_comm; auto.

  Admitted.

Instance TransfLinkSymbtablegen : TransfLink match_prog :=
  link_transf_symbtablegen.

