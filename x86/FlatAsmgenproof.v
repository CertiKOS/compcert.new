(* ******************* *)
(* Author: Yuting Wang *)
(* Date:   Feb 7, 2018 *)
(* ******************* *)

(** Correctness proof for the FlatAsm generation **)

Require Import Coqlib Integers Values Maps AST.
Require Import Memtype Memory.
Require Import Asm RawAsmgen.
Require Import FlatAsm FlatAsmgen.
Require Import Sect.
Require Import Events.
Require Import StackADT.
Require Import Linking Errors.
Require Import Globalenvs FlatAsmGlobenv.
Require Import RawAsmgen.
Require Import AsmFacts.

Ltac monadInvX1 H :=
  match type of H with
  | (OK _ = OK _) =>
      inversion H; clear H; try subst
  | (Error _ = OK _) =>
      discriminate
  | (bind ?F ?G = OK ?X) =>
      let x := fresh "x" in (
      let EQ1 := fresh "EQ" in (
      let EQ2 := fresh "EQ" in (
      destruct (bind_inversion F G H) as [x [EQ1 EQ2]];
      clear H;
      try (monadInvX1 EQ2))))
  | (bind2 ?F ?G = OK ?X) =>
      let x1 := fresh "x" in (
      let x2 := fresh "x" in (
      let EQ1 := fresh "EQ" in (
      let EQ2 := fresh "EQ" in (
      destruct (bind2_inversion F G H) as [x1 [x2 [EQ1 EQ2]]];
      clear H;
      try (monadInvX1 EQ2)))))
  | (match ?X with left _ => _ | right _ => assertion_failed end = OK _) =>
      destruct X; [try (monadInvX1 H) | discriminate]
  | (match (negb ?X) with true => _ | false => assertion_failed end = OK _) =>
      destruct X as [] eqn:?; [discriminate | try (monadInvX1 H)]
  | (match ?X with true => _ | false => assertion_failed end = OK _) =>
      destruct X as [] eqn:?; [try (monadInvX1 H) | discriminate]
  | (mmap ?F ?L = OK ?M) =>
      generalize (mmap_inversion F L H); intro
  | (match ?X with Some _ => _ | None => _ end = _) =>
      let EQ := fresh "EQ" in (
      destruct X eqn:EQ; try (monadInvX1 H))
  (* | (match ?X with inl _ => _ | inr _ => _ end = OK _) => *)
  (*     let EQ := fresh "EQ" in ( *)
  (*     destruct X eqn:EQ; try (monadInvX1 H)) *)
  (* | (match ?X with Asm.Addrmode _ _ _ => _ end = _) => *)
  (*     let EQ := fresh "EQ" in ( *)
  (*       destruct X eqn:EQ; try (monadInvX1 H)) *)
  end.

Ltac monadInvX H :=
  monadInvX1 H ||
  match type of H with
  | (?F _ _ _ _ _ _ _ _ = OK _) =>
      ((progress simpl in H) || unfold F in H); monadInvX1 H
  | (?F _ _ _ _ _ _ _ = OK _) =>
      ((progress simpl in H) || unfold F in H); monadInvX1 H
  | (?F _ _ _ _ _ _ = OK _) =>
      ((progress simpl in H) || unfold F in H); monadInvX1 H
  | (?F _ _ _ _ _ = OK _) =>
      ((progress simpl in H) || unfold F in H); monadInvX1 H
  | (?F _ _ _ _ = OK _) =>
      ((progress simpl in H) || unfold F in H); monadInvX1 H
  | (?F _ _ _ = OK _) =>
      ((progress simpl in H) || unfold F in H); monadInvX1 H
  | (?F _ _ = OK _) =>
      ((progress simpl in H) || unfold F in H); monadInvX1 H
  | (?F _ = OK _) =>
      ((progress simpl in H) || unfold F in H); monadInvX1 H
  end.


Section WITHMEMORYMODEL.
  
Context `{memory_model: Mem.MemoryModel }.
Existing Instance inject_perm_upto_writable.

Definition match_prog (p: Asm.program) (tp: FlatAsm.program) :=
  transf_program p = OK tp.


Section PRESERVATION.

Variable prog: Asm.program.
Variable tprog: FlatAsm.program.
Hypothesis TRANSF: match_prog prog tprog.

Let ge := Genv.globalenv prog.
Let tge := globalenv tprog.

Definition regset_inject (j:meminj) (rs rs' : regset) : Prop :=
  forall r, Val.inject j (rs r) (rs' r).

(** Agreement between a memory injection from Asm to the flat memory and 
    the mappings for sections, global id and labels *)    
Record match_sminj (gm: GID_MAP_TYPE) (lm: LABEL_MAP_TYPE) (mj: meminj) : Type :=
  mk_match_sminj {
      (* agree_sminj : forall b id sid ofs ofs', *)
      (*   Genv.find_symbol ge id = Some b -> *)
      (*   gm id = Some (sid,ofs) -> PTree.get sid sm = Some ofs' -> *)
      (*   mj b = Some (mem_block, Ptrofs.unsigned (Ptrofs.add ofs ofs')); *)
 
      agree_sminj_instr :  forall b b' f ofs ofs' i,
        Genv.find_funct_ptr ge b = Some (Internal f) -> 
        Asm.find_instr (Ptrofs.unsigned ofs) (Asm.fn_code f) = Some i ->
        mj b = Some (b', ofs') -> 
        exists id i' ofs1, 
          Genv.find_instr tge (Ptrofs.add ofs (Ptrofs.repr ofs')) = Some i' /\
          Genv.find_symbol ge id = Some b /\
          transl_instr gm lm ofs1 id i = OK i';

      agree_sminj_glob : forall id b gloc,
        Genv.find_symbol ge id = Some b ->
        gm id = Some gloc ->
        exists ofs', get_sect_label_offset0 (Genv.genv_smap tge) gloc = Some ofs' /\
                mj b = Some (mem_block, Ptrofs.unsigned ofs');
      
    }.

Definition gid_map_for_undef_syms (gm: GID_MAP_TYPE) :=
  forall id, Genv.find_symbol ge id = None -> gm id = None.


Definition globs_inj_into_flatmem (mj:meminj) := 
  forall b g b' ofs',
    Genv.find_def ge b = Some g -> 
    mj b = Some (b', ofs') -> b' = mem_block.

Definition funs_inj_into_flatmem (mj:meminj) := 
  forall b f b' ofs',
    Genv.find_funct_ptr ge b = Some f -> 
    mj b = Some (b', ofs') -> b' = mem_block.

Lemma globs_to_funs_inj_into_flatmem : forall (j:meminj),
    globs_inj_into_flatmem j -> funs_inj_into_flatmem j.
Proof.
  unfold globs_inj_into_flatmem, funs_inj_into_flatmem. 
  unfold Genv.find_funct_ptr. intros.
  destruct (Genv.find_def ge b) eqn: FDEF; try congruence.
  destruct g; try congruence. 
  inv H0. eapply H; eauto.
Qed.


Definition valid_instr_offset_is_internal (mj:meminj) :=
  forall b f ofs i ofs',
    Genv.find_funct_ptr ge b = Some (Internal f) ->
    find_instr (Ptrofs.unsigned ofs) (Asm.fn_code f) = Some i ->
    mj b = Some (mem_block, ofs') ->
    Genv.genv_is_instr_internal tge (Ptrofs.add ofs (Ptrofs.repr ofs')) = true.    

Definition extfun_entry_is_external (mj:meminj) :=
  forall b b' f ofs,
    Genv.find_funct_ptr ge b = Some (External f) ->
    mj b = Some (b', ofs) ->
    Genv.genv_is_instr_internal tge (Ptrofs.repr ofs) = false.


Definition def_frame_inj m := (fun n => if lt_dec n (length (Mem.stack_adt m)) then Some O else None).


Lemma store_pres_def_frame_inj : forall chunk m1 b ofs v m1',
    Mem.store chunk m1 b ofs v = Some m1' -> 
    forall n, def_frame_inj m1 n = def_frame_inj m1' n.
Proof.
  unfold def_frame_inj. intros.
  exploit Mem.store_stack_blocks; eauto. intros. rewrite H0.
  auto.
Qed.

Lemma storev_pres_def_frame_inj : forall chunk m1 a r m1',
    Mem.storev chunk m1 a r = Some m1' -> 
    forall n, def_frame_inj m1 n = def_frame_inj m1' n.
Proof.
  unfold Mem.storev. intros.
  destruct a in H; try congruence.
  eapply store_pres_def_frame_inj; eauto.
Qed.
  

Definition match_find_funct (j:meminj) :=
  forall b f ofs,
  Genv.find_funct_ptr ge b = Some (External f) ->
  j b = Some (mem_block, ofs) ->
  Genv.find_funct_offset tge (Ptrofs.repr ofs) = Some (External f).

Definition glob_block_valid (m:mem) := 
  forall b g, Genv.find_def ge b = Some g -> Mem.valid_block m b.

Inductive match_states: Asm.state -> FlatAsm.state -> Prop :=
| match_states_intro: forall (j:meminj) (rs: regset) (m: mem) (rs': regset) (m':mem)
                        (gm: GID_MAP_TYPE) (lm: LABEL_MAP_TYPE)
                        (MINJ: Mem.inject j (def_frame_inj m) m m')
                        (MATCHSMINJ: match_sminj gm lm j)
                        (GINJFLATMEM: globs_inj_into_flatmem j)
                        (INSTRINTERNAL: valid_instr_offset_is_internal j)
                        (EXTEXTERNAL: extfun_entry_is_external j)
                        (MATCHFINDFUNCT: match_find_funct j)
                        (RSINJ: regset_inject j rs rs')
                        (GBVALID: glob_block_valid m)
                        (GMUNDEF: gid_map_for_undef_syms gm),
    match_states (State rs m) (State rs' m').


Context `{external_calls_ops : !ExternalCallsOps mem }.
Context `{!EnableBuiltins mem}.
Existing Instance Asm.mem_accessors_default.
Existing Instance FlatAsm.mem_accessors_default.

Lemma eval_builtin_arg_inject : forall gm lm j m m' rs rs' sp sp' arg varg arg',
    match_sminj gm lm j ->
    gid_map_for_undef_syms gm ->
    Mem.inject j (def_frame_inj m) m m' ->
    regset_inject j rs rs' ->
    Val.inject j sp sp' ->
    transl_builtin_arg gm arg = OK arg' ->
    eval_builtin_arg ge rs sp m arg varg ->
    exists varg', FlatAsmBuiltin.eval_builtin_arg _ _ preg tge rs' sp' m' arg' varg' /\
             Val.inject j varg varg'.
Proof.
  unfold regset_inject. 
  induction arg; intros; inv H5;
    try (eexists; split; auto; monadInv H4; constructor).
  - monadInv H4. exploit Mem.loadv_inject; eauto.
    eapply Val.offset_ptr_inject; eauto.
    intros (v2 & MVLOAD & LINJ).
    eexists; split; eauto.
    constructor; auto.
  - monadInv H4. 
    exists (Val.offset_ptr sp' ofs). split; try (eapply Val.offset_ptr_inject; eauto).
    constructor.
  - monadInvX H4. unfold Senv.symbol_address in H10.
    destruct (Senv.find_symbol ge id) eqn:FINDSYM.
    + inv H. exploit agree_sminj_glob0; eauto. 
      unfold Senv.find_symbol in FINDSYM. simpl in FINDSYM. apply FINDSYM.
      intros (ofs' & GLOFS & JB).
      exploit Mem.loadv_inject; eauto.
      intros (varg' & LOADV & VARGINJ).
      exists varg'. split; auto.
      apply FlatAsmBuiltin.eval_BA_loadglobal with (Ptrofs.add ofs ofs').
      * exploit get_sect_label_offset0_offset; eauto.
      * rewrite Ptrofs.repr_unsigned in *. auto.
    + simpl in H10. congruence.
  - monadInvX H4. unfold Senv.symbol_address.
    destruct (Senv.find_symbol ge id) eqn:FINDSYM.
    + inv H. exploit agree_sminj_glob0; eauto. 
      unfold Senv.find_symbol in FINDSYM. simpl in FINDSYM. apply FINDSYM.
      intros (ofs' & GLOFS & JB).
      exists (flatptr (Ptrofs.add ofs ofs')). split; auto.
      apply FlatAsmBuiltin.eval_BA_addrglobal.
      * exploit get_sect_label_offset0_offset; eauto.
      * unfold flatptr. eapply Val.inject_ptr; eauto.
        rewrite Ptrofs.repr_unsigned. auto.
    + unfold Senv.find_symbol in FINDSYM. simpl in FINDSYM.
      unfold gid_map_for_undef_syms in *. exploit H0; eauto.
      congruence.
  - monadInv H4.
    exploit IHarg1; eauto. intros (vhi' & EVAL1 & VINJ1).
    exploit IHarg2; eauto. intros (vlo' & EVAL2 & VINJ2).
    exists (Val.longofwords vhi' vlo'); split.
    + constructor; auto.
    + apply Val.longofwords_inject; eauto.
Qed.

Lemma eval_builtin_args_inject : forall gm lm j m m' rs rs' sp sp' args vargs args',
    match_sminj gm lm j ->
    gid_map_for_undef_syms gm ->
    Mem.inject j (def_frame_inj m) m m' ->
    regset_inject j rs rs' ->
    Val.inject j sp sp' ->
    transl_builtin_args gm args = OK args' ->
    eval_builtin_args ge rs sp m args vargs ->
    exists vargs', FlatAsmBuiltin.eval_builtin_args _ _ preg tge rs' sp' m' args' vargs' /\
             Val.inject_list j vargs vargs'.
Proof.
  induction args; intros; simpl. 
  - inv H4. inv H5. exists nil. split; auto.
    unfold FlatAsmBuiltin.eval_builtin_args. apply list_forall2_nil.
  - monadInv H4. inv H5.
    exploit eval_builtin_arg_inject; eauto. 
    intros (varg' & EVARG & VINJ).
    exploit IHargs; eauto. 
    intros (vargs' & EVARGS & VSINJ).
    exists (varg' :: vargs'). split; auto.
    unfold FlatAsmBuiltin.eval_builtin_args. 
    apply list_forall2_cons; auto.
Qed.

Lemma extcall_arg_inject : forall rs1 rs2 m1 m2 l arg1 j,
    extcall_arg rs1 m1 l arg1 ->
    Mem.inject j (def_frame_inj m1) m1 m2 ->
    regset_inject j rs1 rs2 ->
    exists arg2,
      Val.inject j arg1 arg2 /\
      extcall_arg rs2 m2 l arg2.
Proof.
  intros. inv H.
  - unfold regset_inject in *.
    specialize (H1 (Asm.preg_of r)). eexists; split; eauto.
    constructor.
  - exploit Mem.loadv_inject; eauto.
    apply Val.offset_ptr_inject. apply H1.
    intros (arg2 & MLOADV & ARGINJ).
    exists arg2. split; auto.
    eapply extcall_arg_stack; eauto.
Qed.

Lemma extcall_arg_pair_inject : forall rs1 rs2 m1 m2 lp arg1 j,
    extcall_arg_pair rs1 m1 lp arg1 ->
    Mem.inject j (def_frame_inj m1) m1 m2 ->
    regset_inject j rs1 rs2 ->
    exists arg2,
      Val.inject j arg1 arg2 /\
      extcall_arg_pair rs2 m2 lp arg2.
Proof.
  intros. inv H.
  - exploit extcall_arg_inject; eauto. 
    intros (arg2 & VINJ & EXTCALL).
    exists arg2. split; auto. constructor. auto.
  - exploit (extcall_arg_inject rs1 rs2 m1 m2 hi vhi); eauto. 
    intros (arghi & VINJHI & EXTCALLHI).
    exploit (extcall_arg_inject rs1 rs2 m1 m2 lo vlo); eauto. 
    intros (arglo & VINJLO & EXTCALLLO).
    exists (Val.longofwords arghi arglo). split.
    + apply Val.longofwords_inject; auto.
    + constructor; auto.
Qed.

Lemma extcall_arguments_inject_aux : forall rs1 rs2 m1 m2 locs args1 j,
   list_forall2 (extcall_arg_pair rs1 m1) locs args1 ->
    Mem.inject j (def_frame_inj m1) m1 m2 ->
    regset_inject j rs1 rs2 ->
    exists args2,
      Val.inject_list j args1 args2 /\
      list_forall2 (extcall_arg_pair rs2 m2) locs args2.
Proof.
  induction locs; simpl; intros; inv H.
  - exists nil. split.
    + apply Val.inject_list_nil.
    + unfold Asm.extcall_arguments. apply list_forall2_nil.
  - exploit extcall_arg_pair_inject; eauto.
    intros (arg2 & VINJARG2 & EXTCALLARG2).
    exploit IHlocs; eauto.
    intros (args2 & VINJARGS2 & EXTCALLARGS2).
    exists (arg2 :: args2). split; auto.
    apply list_forall2_cons; auto.
Qed.

Lemma extcall_arguments_inject : forall rs1 rs2 m1 m2 ef args1 j,
    Asm.extcall_arguments rs1 m1 (ef_sig ef) args1 ->
    Mem.inject j (def_frame_inj m1) m1 m2 ->
    regset_inject j rs1 rs2 ->
    exists args2,
      Val.inject_list j args1 args2 /\
      Asm.extcall_arguments rs2 m2 (ef_sig ef) args2.
Proof.
  unfold Asm.extcall_arguments. intros.
  eapply extcall_arguments_inject_aux; eauto.
Qed.

Axiom external_call_inject : forall j vargs1 vargs2 m1 m2 m1' vres1 t ef,
    Val.inject_list j vargs1 vargs2 ->
    Mem.inject j (def_frame_inj m1) m1 m2 ->
    external_call ef ge vargs1 m1 t vres1 m1' ->
    exists j' vres2 m2',
      external_call ef dummy_senv vargs2 m2 t vres2 m2' /\ 
      Val.inject j' vres1 vres2 /\ Mem.inject j' (def_frame_inj m1') m1' m2' /\
      inject_incr j j' /\
      inject_separated j j' m1 m2.

Axiom  external_call_valid_block: forall ef ge vargs m1 t vres m2 b,
    external_call ef ge vargs m1 t vres m2 -> Mem.valid_block m1 b -> Mem.valid_block m2 b.

Lemma extcall_pres_glob_block_valid : forall ef ge vargs m1 t vres m2,
  external_call ef ge vargs m1 t vres m2 -> glob_block_valid m1 -> glob_block_valid m2.
Proof.
  unfold glob_block_valid in *. intros.
  eapply external_call_valid_block; eauto.
Qed.

Lemma regset_inject_incr : forall j j' rs rs',
    regset_inject j rs rs' ->
    inject_incr j j' ->
    regset_inject j' rs rs'.
Proof.
  unfold inject_incr, regset_inject. intros.
  specialize (H r).
  destruct (rs r); inversion H; subst; auto.
  eapply Val.inject_ptr. apply H0. eauto. auto.
Qed.

Lemma undef_regs_pres_inject : forall j rs rs' regs,
  regset_inject j rs rs' ->
  regset_inject j (Asm.undef_regs regs rs) (Asm.undef_regs regs rs').
Proof.
  unfold regset_inject. intros. apply val_inject_undef_regs.
  auto.
Qed.    

Lemma Pregmap_gsspec_alt : forall (A : Type) (i j : Pregmap.elt) (x : A) (m : Pregmap.t A),
    (m # j <- x) i  = (if Pregmap.elt_eq i j then x else m i).
Proof.
  intros. apply Pregmap.gsspec.
Qed.

Lemma regset_inject_expand : forall j rs1 rs2 v1 v2 r,
  regset_inject j rs1 rs2 ->
  Val.inject j v1 v2 ->
  regset_inject j (rs1 # r <- v1) (rs2 # r <- v2).
Proof.
  intros. unfold regset_inject. intros.
  repeat rewrite Pregmap_gsspec_alt. 
  destruct (Pregmap.elt_eq r0 r); auto.
Qed.

Lemma set_res_pres_inject : forall res j rs1 rs2,
    regset_inject j rs1 rs2 ->
    forall vres1 vres2,
    Val.inject j vres1 vres2 ->
    regset_inject j (set_res res vres1 rs1) (set_res res vres2 rs2).
Proof.
  induction res; auto; simpl; unfold regset_inject; intros.
  - rewrite Pregmap_gsspec_alt. destruct (Pregmap.elt_eq r x); subst.
    + rewrite Pregmap.gss. auto.
    + rewrite Pregmap.gso; auto.
  - exploit (Val.hiword_inject j vres1 vres2); eauto. intros. 
    exploit (Val.loword_inject j vres1 vres2); eauto. intros.
    apply IHres2; auto.
Qed.


Lemma nextinstr_pres_inject : forall j rs1 rs2 sz,
    regset_inject j rs1 rs2 ->
    regset_inject j (nextinstr rs1 sz) (nextinstr rs2 sz).
Proof.
  unfold nextinstr. intros. apply regset_inject_expand; auto.
  apply Val.offset_ptr_inject. auto.
Qed.  

Lemma set_pair_pres_inject : forall j rs1 rs2 v1 v2 loc,
    regset_inject j rs1 rs2 ->
    Val.inject j v1 v2 ->
    regset_inject j (set_pair loc v1 rs1) (set_pair loc v2 rs2).
Proof.
  intros. unfold set_pair, Asm.set_pair. destruct loc; simpl.
  - apply regset_inject_expand; auto.
  - apply regset_inject_expand; auto.
    apply regset_inject_expand; auto.
    apply Val.hiword_inject; auto.
    apply Val.loword_inject; auto.
Qed.

Lemma vinject_pres_not_vundef : forall j v1 v2,
  Val.inject j v1 v2 -> v1 <> Vundef -> v2 <> Vundef.
Proof.
  intros. destruct v1; inversion H; subst; auto.
  congruence.
Qed.

Lemma vinject_pres_has_type : forall j v1 v2 t,
    Val.inject j v1 v2 -> v1 <> Vundef ->
    Val.has_type v1 t -> Val.has_type v2 t.
Proof.
  intros. destruct v1; inversion H; subst; simpl in H; auto. 
  congruence.
Qed.

Lemma inject_decr : forall b j j' m1 m2 b' ofs,
  Mem.valid_block m1 b -> inject_incr j j' -> inject_separated j j' m1 m2 ->
  j' b = Some (b', ofs) -> j b = Some (b', ofs).
Proof.
  intros. destruct (j b) eqn:JB.
  - unfold inject_incr in *. destruct p. exploit H0; eauto.
    intros. congruence.
  - unfold inject_separated in *. exploit H1; eauto.
    intros (NVALID1 & NVALID2). congruence.
Qed.

Lemma inject_pres_match_sminj : 
  forall j j' m1 m2 gm lm (ms: match_sminj gm lm j), 
    glob_block_valid m1 -> inject_incr j j' -> inject_separated j j' m1 m2 -> 
    match_sminj gm lm j'.
Proof.
  unfold glob_block_valid.
  intros. inversion ms. constructor; intros.
  - 
    eapply agree_sminj_instr0; eauto.
    instantiate (1:=b').
    unfold Genv.find_funct_ptr in H2. destruct (Genv.find_def ge b) eqn:FDEF; try congruence.
    exploit H; eauto. intros.
    eapply inject_decr; eauto.
  - 
    exploit agree_sminj_glob0; eauto. 
    intros (ofs' & GLBL & JB).
    eexists; eauto.
Qed.

Lemma inject_pres_globs_inj_into_flatmem : forall j j' m1 m2,
    glob_block_valid m1 -> inject_incr j j' -> inject_separated j j' m1 m2 -> 
    globs_inj_into_flatmem j -> globs_inj_into_flatmem j'.
Proof.
  unfold globs_inj_into_flatmem, glob_block_valid. intros.
  exploit H; eauto. intros.
  assert (j b = Some (b', ofs')) by (eapply inject_decr; eauto).
  eapply H2; eauto.
Qed.

Lemma inject_pres_valid_instr_offset_is_internal : forall j j' m1 m2,
    glob_block_valid m1 -> inject_incr j j' -> inject_separated j j' m1 m2 -> 
    valid_instr_offset_is_internal j -> valid_instr_offset_is_internal j'.
Proof.
  unfold glob_block_valid.
  unfold valid_instr_offset_is_internal. intros.
  eapply H2; eauto.
  unfold Genv.find_funct_ptr in H3. destruct (Genv.find_def ge b) eqn:FDEF; try congruence.
  exploit H; eauto. intros.
  eapply inject_decr; eauto.
Qed.

Lemma inject_pres_extfun_entry_is_external : forall j j' m1 m2,
    glob_block_valid m1 -> inject_incr j j' -> inject_separated j j' m1 m2 -> 
    extfun_entry_is_external j -> extfun_entry_is_external j'.
Proof.
  unfold glob_block_valid.
  unfold extfun_entry_is_external. intros.
  eapply H2; eauto.
  instantiate (1:=b').
  unfold Genv.find_funct_ptr in H3. destruct (Genv.find_def ge b) eqn:FDEF; try congruence.
  exploit H; eauto. intros.
  eapply inject_decr; eauto.
Qed.

Lemma inject_pres_match_find_funct : forall j j' m1 m2,
    glob_block_valid m1 -> inject_incr j j' -> inject_separated j j' m1 m2 -> 
    match_find_funct j -> match_find_funct j'.
Proof.
  unfold glob_block_valid, match_find_funct. intros.
  eapply H2; eauto.
  unfold Genv.find_funct_ptr in H3. destruct (Genv.find_def ge b) eqn:FDEF; try congruence.
  exploit H; eauto. intros.
  eapply inject_decr; eauto.
Qed.  

Remark mul_inject:
  forall f v1 v1' v2 v2',
  Val.inject f v1 v1' ->
  Val.inject f v2 v2' ->
  Val.inject f (Val.mul v1 v2) (Val.mul v1' v2').
Proof.
  intros. unfold Val.mul. destruct v1, v2; simpl; auto.
  inversion H; inversion H0; subst. auto.
Qed.

Remark mull_inject:
  forall f v1 v1' v2 v2',
  Val.inject f v1 v1' ->
  Val.inject f v2 v2' ->
  Val.inject f (Val.mull v1 v2) (Val.mull v1' v2').
Proof.
Proof.
  intros. unfold Val.mull. destruct v1, v2; simpl; auto.
  inversion H; inversion H0; subst. auto.
Qed.


Lemma inject_symbol_sectlabel : forall gm lm j id lbl ofs,
    match_sminj gm lm j ->
    gm id = Some lbl ->
    Val.inject j (Genv.symbol_address ge id ofs) (Genv.get_label_addr tge lbl ofs).
Proof.
  unfold Genv.symbol_address, Genv.get_label_addr.
  unfold get_sect_label_addr. intros.
  destruct (Genv.find_symbol ge id) eqn:FINDSYM; auto.
  inv H. exploit agree_sminj_glob0; eauto.
  intros (ofs' & SBOFS & JB).
  unfold get_sect_label_addr0. rewrite SBOFS.
  unfold flatptr; simpl. 
  eapply Val.inject_ptr. eauto.
  rewrite Ptrofs.repr_unsigned. apply Ptrofs.add_commut.
Qed.

Lemma add_undef : forall v,
  Val.add v Vundef = Vundef.
Proof.
  intros; destruct v; simpl; auto.
Qed.

Lemma addl_undef : forall v,
  Val.addl v Vundef = Vundef.
Proof.
  intros; destruct v; simpl; auto.
Qed.


Lemma eval_addrmode32_inject: forall gm lm j a1 a2 rs1 rs2,
    match_sminj gm lm j ->
    regset_inject j rs1 rs2 ->
    transl_addr_mode gm a1 = OK a2 ->
    Val.inject j (Asm.eval_addrmode32 ge a1 rs1) (FlatAsm.eval_addrmode32 tge a2 rs2).
Proof.
  intros. unfold Asm.eval_addrmode32, FlatAsm.eval_addrmode32.
  destruct a1, a2. destruct base, ofs, const; simpl in *; inv H1.
  - destruct p. apply Val.add_inject; auto.
    destruct (zeq z0 1); apply Val.add_inject; auto.
    apply mul_inject; auto.
  - destruct p0. monadInvX H3. monadInvX EQ.
    destruct p. apply Val.add_inject; auto.
    destruct (zeq z 1). 
    + apply Val.add_inject; auto.
      eapply inject_symbol_sectlabel; eauto.
    + apply Val.add_inject; auto.
      apply mul_inject; auto.
      eapply inject_symbol_sectlabel; eauto.
  - apply Val.add_inject; auto.
    simpl. repeat rewrite Int.add_zero_l. 
    auto.
  - monadInvX H3. destruct p. monadInvX EQ.
    destruct (Genv.symbol_address ge i0 i1) eqn:SYMADDR; 
      try now (rewrite add_undef; auto).
    apply Val.add_inject; eauto.
    simpl. rewrite Int.add_zero_l.
    exploit inject_symbol_sectlabel; eauto.
    rewrite SYMADDR. intros. inv H1.
    rewrite Int.add_zero_l. auto.
  - destruct p. destruct (zeq z0 1); simpl.
    + destruct (Val.add (rs1 i) (Vint (Int.repr z))) eqn:EQ; auto.
      assert (Val.inject j (Val.add (rs1 i) (Vint (Int.repr z))) (Val.add (rs2 i) (Vint (Int.repr z)))).
      apply Val.add_inject; auto.
      rewrite EQ in *. inv H1. setoid_rewrite <- H4. auto.
    + destruct (Val.add (Val.mul (rs1 i) (Vint (Int.repr z0))) (Vint (Int.repr z))) eqn:EQ; auto.
      assert (Val.inject j (Val.add (Val.mul (rs1 i) (Vint (Int.repr z0))) (Vint (Int.repr z)))
                           (Val.add (Val.mul (rs2 i) (Vint (Int.repr z0))) (Vint (Int.repr z)))).
      apply Val.add_inject; auto. apply mul_inject; auto.
      rewrite EQ in *. inv H1. setoid_rewrite <- H4. auto.
  - monadInvX H3. destruct p0. monadInvX EQ.
    destruct p. destruct (zeq z 1).
    + destruct (Val.add (rs1 i1) (Genv.symbol_address ge i i0)) eqn:EQ; auto.
      rewrite Int.add_zero_l. simpl.
      assert (Val.inject j (Val.add (rs1 i1) (Genv.symbol_address ge i i0))
                           (Val.add (rs2 i1) (Genv.get_label_addr tge s i0))).
      apply Val.add_inject; auto. eapply inject_symbol_sectlabel; eauto.
      rewrite EQ in *. inv H1.  setoid_rewrite <- H4. 
      rewrite Int.add_zero_l. auto.
    + destruct (Val.add (Val.mul (rs1 i1) (Vint (Int.repr z))) (Genv.symbol_address ge i i0)) eqn:EQ; auto.
      rewrite Int.add_zero_l. simpl.
      assert (Val.inject j (Val.add (Val.mul (rs1 i1) (Vint (Int.repr z))) (Genv.symbol_address ge i i0))
                           (Val.add (Val.mul (rs2 i1) (Vint (Int.repr z))) (Genv.get_label_addr tge s i0))).
      apply Val.add_inject. apply mul_inject; auto.
      eapply inject_symbol_sectlabel; eauto.
      rewrite EQ in *. inv H1.  setoid_rewrite <- H4. 
      rewrite Int.add_zero_l. auto.
  - simpl. repeat rewrite Int.add_zero_l.  auto.
  - monadInvX H3. destruct p. monadInvX EQ.
    destruct (Genv.symbol_address ge i i0) eqn:SYMBEQ; auto.
    exploit inject_symbol_sectlabel; eauto.
    rewrite SYMBEQ. intro INJ. inv INJ.
    simpl. repeat rewrite Int.add_zero_l. auto.
Qed.

Lemma eval_addrmode64_inject: forall gm lm j a1 a2 rs1 rs2,
    match_sminj gm lm j ->
    regset_inject j rs1 rs2 ->
    transl_addr_mode gm a1 = OK a2 ->
    Val.inject j (Asm.eval_addrmode64 ge a1 rs1) (FlatAsm.eval_addrmode64 tge a2 rs2).
Proof.
  intros. unfold Asm.eval_addrmode64, FlatAsm.eval_addrmode64.
  destruct a1, a2. destruct base, ofs, const; simpl in *; inv H1.
  - destruct p. apply Val.addl_inject; auto.
    destruct (zeq z0 1); apply Val.addl_inject; auto.
    apply mull_inject; auto.
  - destruct p0. monadInvX H3. monadInvX EQ.
    destruct p. apply Val.addl_inject; auto.
    destruct (zeq z 1). 
    + apply Val.addl_inject; auto.
      eapply inject_symbol_sectlabel; eauto.
    + apply Val.addl_inject; auto.
      apply mull_inject; auto.
      eapply inject_symbol_sectlabel; eauto.
  - apply Val.addl_inject; auto.
    simpl. repeat rewrite Int.add_zero_l. 
    auto.
  - monadInvX H3. destruct p. monadInvX EQ.
    destruct (Genv.symbol_address ge i0 i1) eqn:SYMADDR; 
      try now (rewrite addl_undef; auto).
    + apply Val.addl_inject; eauto.
      simpl. rewrite Int64.add_zero_l.
      exploit inject_symbol_sectlabel; eauto.
      rewrite SYMADDR. intros. inv H1.
      rewrite Int64.add_zero_l. auto.
    + rewrite Ptrofs.add_zero.
      destruct Archi.ptr64 eqn:ARCH. 
      * simpl. apply Val.addl_inject; auto.
        exploit inject_symbol_sectlabel; eauto. rewrite SYMADDR.
        inversion 1; subst. rewrite ARCH.
        rewrite Ptrofs.add_zero. rewrite <- H4 in *. auto.
      * simpl. apply Val.addl_inject; auto.
  - destruct p. destruct (zeq z0 1); simpl.
    + destruct (Val.addl (rs1 i) (Vlong (Int64.repr z))) eqn:EQ; auto.
      * assert (Val.inject j (Val.addl (rs1 i) (Vlong (Int64.repr z))) (Val.addl (rs2 i) (Vlong (Int64.repr z)))).
        apply Val.addl_inject; auto.
        rewrite EQ in *. inv H1. setoid_rewrite <- H4. auto.
      * assert (Val.inject j (Val.addl (rs1 i) (Vlong (Int64.repr z)))
                             (Val.addl (rs2 i) (Vlong (Int64.repr z)))).
        apply Val.addl_inject; auto.
        rewrite EQ in *. inversion H1; subst. destruct Archi.ptr64; auto.
        rewrite Ptrofs.add_zero. setoid_rewrite <- H4.
        rewrite Ptrofs.add_zero. congruence.
    + assert (Val.inject j (Val.addl (Val.mull (rs1 i) (Vlong (Int64.repr z0))) (Vlong (Int64.repr z)))
                         (Val.addl (Val.mull (rs2 i) (Vlong (Int64.repr z0))) (Vlong (Int64.repr z)))).
      apply Val.addl_inject; auto. apply mull_inject; auto.
      destruct (Val.addl (Val.mull (rs1 i) (Vlong (Int64.repr z0))) (Vlong (Int64.repr z))) eqn:EQ; auto.
      * inversion H1; subst. setoid_rewrite <- H4. auto.
      * destruct Archi.ptr64 eqn:ARCHI; auto.
        inversion H1; subst. setoid_rewrite <- H4. 
        repeat rewrite Ptrofs.add_zero. congruence.
  - monadInvX H3. destruct p0. monadInvX EQ.
    destruct p. destruct (zeq z 1).
    + simpl.
      assert (Val.inject j (Val.addl (rs1 i1) (Genv.symbol_address ge i i0))
                           (Val.addl (rs2 i1) (Genv.get_label_addr tge s i0))).
      apply Val.addl_inject; auto. eapply inject_symbol_sectlabel; eauto.
      destruct (Val.addl (rs1 i1) (Genv.symbol_address ge i i0)) eqn:EQ; auto.
      * rewrite Int64.add_zero_l. inversion H1; subst. setoid_rewrite <- H4.
        rewrite Int64.add_zero_l. auto.
      * destruct Archi.ptr64 eqn:ARCHI; auto.
        rewrite Ptrofs.add_zero. inversion H1; subst. setoid_rewrite <- H4.
        rewrite Ptrofs.add_zero. congruence.
    + simpl.
      assert (Val.inject j (Val.addl (Val.mull (rs1 i1) (Vlong (Int64.repr z))) (Genv.symbol_address ge i i0))
                           (Val.addl (Val.mull (rs2 i1) (Vlong (Int64.repr z))) (Genv.get_label_addr tge s i0))).
      apply Val.addl_inject; auto. apply mull_inject; auto.
      eapply inject_symbol_sectlabel; eauto.
      destruct (Val.addl (Val.mull (rs1 i1) (Vlong (Int64.repr z))) (Genv.symbol_address ge i i0)); auto.
      * inversion H1; subst. rewrite Int64.add_zero_l.
        setoid_rewrite <- H4. rewrite Int64.add_zero_l. auto.
      * destruct Archi.ptr64 eqn:ARCHI; auto.
        rewrite Ptrofs.add_zero. inversion H1; subst. setoid_rewrite <- H4.
        rewrite Ptrofs.add_zero. congruence. 
  - simpl. repeat rewrite Int64.add_zero_l. auto.
  - monadInvX H3. destruct p. monadInvX EQ.
    destruct (Genv.symbol_address ge i i0) eqn:SYMBEQ; auto.
    + exploit inject_symbol_sectlabel; eauto.
      rewrite SYMBEQ. intro INJ. inv INJ.
      simpl. repeat rewrite Int.add_zero_l. auto.
    + destruct Archi.ptr64 eqn:ARCHI; auto. simpl.
      repeat rewrite Ptrofs.add_zero. 
      assert (Val.inject j (Genv.symbol_address ge i i0) (Genv.get_label_addr tge s i0)).
      eapply inject_symbol_sectlabel; eauto.
      rewrite SYMBEQ in *. inversion H1; subst.
      destruct Archi.ptr64 eqn:ARCHI1.
      repeat rewrite Ptrofs.add_zero. congruence.
      congruence.
Qed.

Lemma eval_addrmode_inject: forall gm lm j a1 a2 rs1 rs2,
    match_sminj gm lm j ->
    regset_inject j rs1 rs2 ->
    transl_addr_mode gm a1 = OK a2 ->
    Val.inject j (Asm.eval_addrmode ge a1 rs1) (FlatAsm.eval_addrmode tge a2 rs2).
Proof.
  intros. unfold Asm.eval_addrmode, eval_addrmode. destruct Archi.ptr64.
  + eapply eval_addrmode64_inject; eauto.
  + eapply eval_addrmode32_inject; eauto.
Qed.

Lemma exec_load_step: forall j rs1 rs2 m1 m2 rs1' m1' gm lm sz chunk rd a1 a2
                          (MINJ: Mem.inject j (def_frame_inj m1) m1 m2)
                          (MATCHSMINJ: match_sminj gm lm j)
                          (GINJFLATMEM: globs_inj_into_flatmem j)
                          (INSTRINTERNAL: valid_instr_offset_is_internal j)
                          (EXTEXTERNAL: extfun_entry_is_external j)
                          (MATCHFINDFUNCT: match_find_funct j)
                          (RSINJ: regset_inject j rs1 rs2)
                          (GBVALID: glob_block_valid m1)
                          (GMUNDEF: gid_map_for_undef_syms gm),
    Asm.exec_load ge chunk m1 a1 rs1 rd sz = Next rs1' m1' ->
    transl_addr_mode gm a1 = OK a2 ->
    exists rs2' m2',
      FlatAsm.exec_load tge chunk m2 a2 rs2 rd sz = Next rs2' m2' /\
      match_states (State rs1' m1') (State rs2' m2').
Proof.
  intros. unfold Asm.exec_load in *.  
  exploit eval_addrmode_inject; eauto. intro EMODINJ. unfold Next in H.
  destruct (Mem.loadv chunk m1 (Asm.eval_addrmode ge a1 rs1)) eqn:MLOAD; try congruence.
  exploit Mem.loadv_inject; eauto. intros (v2 & MLOADV & VINJ).
  eexists. eexists. split.
  - unfold exec_load. rewrite MLOADV. auto.
  - inv H. eapply match_states_intro; eauto.
    apply nextinstr_pres_inject. apply undef_regs_pres_inject.
    apply regset_inject_expand; eauto.
Qed.

Lemma store_pres_glob_block_valid : forall m1 chunk b v ofs m2,
  Mem.store chunk m1 b ofs v = Some m2 -> glob_block_valid m1 -> glob_block_valid m2.
Proof.
  unfold glob_block_valid in *. intros.
  eapply Mem.store_valid_block_1; eauto.
Qed.

Lemma storev_pres_glob_block_valid : forall m1 chunk ptr v m2,
  Mem.storev chunk m1 ptr v = Some m2 -> glob_block_valid m1 -> glob_block_valid m2.
Proof.
  unfold Mem.storev. intros. destruct ptr; try congruence.
  eapply store_pres_glob_block_valid; eauto.
Qed.

Lemma exec_store_step: forall j rs1 rs2 m1 m2 rs1' m1' gm lm sz chunk r a1 a2 dregs
                         (MINJ: Mem.inject j (def_frame_inj m1) m1 m2)
                         (MATCHSMINJ: match_sminj gm lm j)
                         (GINJFLATMEM: globs_inj_into_flatmem j)
                         (INSTRINTERNAL: valid_instr_offset_is_internal j)
                         (EXTEXTERNAL: extfun_entry_is_external j)
                         (MATCHFINDFUNCT: match_find_funct j)
                         (RSINJ: regset_inject j rs1 rs2)
                         (GBVALID: glob_block_valid m1)
                         (GMUNDEF: gid_map_for_undef_syms gm),
    Asm.exec_store ge chunk m1 a1 rs1 r dregs sz = Next rs1' m1' ->
    transl_addr_mode gm a1 = OK a2 ->
    exists rs2' m2',
      FlatAsm.exec_store tge chunk m2 a2 rs2 r dregs sz = Next rs2' m2' /\
      match_states (State rs1' m1') (State rs2' m2').
Proof.
  intros. unfold Asm.exec_store in *.  
  exploit eval_addrmode_inject; eauto. intro EMODINJ. unfold Next in H.
  destruct (Mem.storev chunk m1 (Asm.eval_addrmode ge a1 rs1) (rs1 r)) eqn:MSTORE; try congruence.
  exploit Mem.storev_mapped_inject; eauto. intros (m2' & MSTOREV & MINJ').
  eexists. eexists. split.
  - unfold exec_store. rewrite MSTOREV. auto.
  - inv H. eapply match_states_intro; eauto.
    eapply Mem.mem_inject_ext; eauto.
    eapply storev_pres_def_frame_inj; eauto.
    apply nextinstr_pres_inject. repeat apply undef_regs_pres_inject. auto.
    eapply storev_pres_glob_block_valid; eauto.
Qed.
  

(** The internal step preserves the invariant *)
Lemma exec_instr_step : forall j rs1 rs2 m1 m2 rs1' m1' gm lm i i' id ofs f
                        (MINJ: Mem.inject j (def_frame_inj m1) m1 m2)
                        (MATCHSMINJ: match_sminj gm lm j)
                        (GINJFLATMEM: globs_inj_into_flatmem j)
                        (INSTRINTERNAL: valid_instr_offset_is_internal j)
                        (EXTEXTERNAL: extfun_entry_is_external j)
                        (MATCHFINDFUNCT: match_find_funct j)
                        (RSINJ: regset_inject j rs1 rs2)
                        (GBVALID: glob_block_valid m1)
                        (GMUNDEF: gid_map_for_undef_syms gm),
    RawAsmgen.exec_instr ge f i rs1 m1 = Next rs1' m1' ->
    transl_instr gm lm ofs id i = OK i' ->
    exists rs2' m2',
      FlatAsm.exec_instr tge i' rs2 m2 = Next rs2' m2' /\
      match_states (State rs1' m1') (State rs2' m2').
Proof.
  intros. destruct i. destruct i; inv H; simpl in *.

  - (* Pmov_rr *)
    monadInv H0. monadInv EQ.
    eexists; eexists; split. constructor.
    unfold instr_size; simpl.
    apply match_states_intro with (j:=j) (gm:=gm) (lm:=lm); auto.
    apply nextinstr_pres_inject.
    apply regset_inject_expand; auto.

  - (* Pmovl_ri *)
    monadInv H0. monadInv EQ.
    eexists; eexists; split. constructor.
    unfold instr_size; simpl.
    apply match_states_intro with (j:=j) (gm:=gm) (lm:=lm); auto.
    apply nextinstr_pres_inject.
    apply undef_regs_pres_inject.
    apply regset_inject_expand; auto.

  - (* Pmovq_ri *)
    monadInv H0. monadInv EQ.
    eexists; eexists; split. constructor.
    unfold instr_size; simpl.
    apply match_states_intro with (j:=j) (gm:=gm) (lm:=lm); auto.
    apply nextinstr_pres_inject.
    apply undef_regs_pres_inject.
    apply regset_inject_expand; auto.

  - (* Pmov_rs *)
    monadInv H0. simpl in EQ. monadInvX1 EQ.
    eexists; eexists; split. constructor.
    unfold instr_size; simpl.
    apply match_states_intro with (j:=j) (gm:=gm) (lm:=lm); auto.
    apply nextinstr_pres_inject.
    apply undef_regs_pres_inject.
    apply regset_inject_expand; auto.
    inv MATCHSMINJ.
    unfold Genv.symbol_address. unfold Genv.get_label_addr0.
    unfold Genv.get_label_addr. 
    destruct (Genv.find_symbol ge id0) eqn:FINDSYM; auto.
    exploit agree_sminj_glob0; eauto.
    intros (ofs' & GLBL & JB).
    unfold get_sect_label_addr0. rewrite GLBL.
    rewrite <- (Ptrofs.add_zero_l ofs').
    eapply Val.inject_ptr; eauto.
    rewrite Ptrofs.repr_unsigned. auto.

  - (* Pmovl_rm *)
    monadInv H0. simpl in EQ. monadInvX1 EQ.
    unfold Asm.exec_instr in H2; simpl in H2.
    unfold instr_size in H2; simpl in H2.    
    exploit exec_load_step; eauto.

  - (* Pmovq_rm *)
    monadInv H0. simpl in EQ. monadInvX1 EQ.
    unfold Asm.exec_instr in H2; simpl in H2.
    unfold instr_size in H2; simpl in H2.    
    exploit exec_load_step; eauto.

  - (* Asm.Pmovl_mr *)
    monadInv H0. simpl in EQ. monadInvX1 EQ.
    unfold Asm.exec_instr in H2; simpl in H2.
    unfold instr_size in H2; simpl in H2.    
    exploit exec_store_step; eauto.

  - 

  - eexists; eexists; split; eauto.
    unfold instr_size; simpl.
    apply match_states_intro with (j:=j) (gm:=gm) (lm:=lm); auto.
    apply nextinstr_pres_inject.
    apply undef_regs_pres_inject.
    apply regset_inject_expand; auto.

  - admit.
  - 



Theorem step_simulation:
  forall S1 t S2,
    RawAsmgen.step ge S1 t S2 ->
    forall S1' (MS: match_states S1 S1'),
    exists S2',
      FlatAsm.step tge S1' t S2' /\
      match_states S2 S2'.
Proof.
  destruct 1; intros; inv MS.

  - (* Internal step *)
    unfold regset_inject in RSINJ. generalize (RSINJ Asm.PC). rewrite H. 
    inversion 1; subst.
    exploit (agree_sminj_instr gm lm j MATCHSMINJ b b2 f ofs delta i); auto.
    intros (id & i' & ofs1 & FITARG & FSYMB & TRANSL).
    exploit (globs_to_funs_inj_into_flatmem j); eauto. inversion 1; subst.
    exploit (exec_instr_step j rs rs'0 m m'0 rs' m' gm lm i i' id ofs1 f); auto.
    intros (rs2' & m2' & FEXEC & MS1).
    exists (State rs2' m2'). split; auto.
    apply FlatAsm.exec_step_internal with (Ptrofs.add ofs (Ptrofs.repr delta)) i'; auto.
    unfold valid_instr_offset_is_internal in INSTRINTERNAL.
    apply INSTRINTERNAL with b f i; auto.
        
  - (* Builtin *)
    unfold regset_inject in RSINJ. generalize (RSINJ Asm.PC). rewrite H.
    inversion 1; subst.
    exploit (agree_sminj_instr gm lm j MATCHSMINJ b b2 f ofs delta (Asm.Pbuiltin ef args res, sz)); auto.
    intros (id & i' & ofs1 & FITARG & FSYMB & TRANSL).
    exploit (globs_to_funs_inj_into_flatmem j); eauto. inversion 1; subst.
    monadInv TRANSL. monadInv EQ.
    set (pbsect := {| sect_block_id := code_sect_id; sect_block_start := Ptrofs.repr ofs1; sect_block_size := Ptrofs.repr (si_size sz) |}).
    fold pbsect in FITARG.
    exploit (eval_builtin_args_inject gm lm j m m'0 rs rs'0 (rs Asm.RSP) (rs'0 Asm.RSP) args vargs x0); auto.
    intros (vargs' & EBARGS & ARGSINJ).
    generalize (external_call_inject j vargs vargs' m m'0 m' vres t ef ARGSINJ MINJ H3).
    intros (j' & vres2 & m2' & EXTCALL & RESINJ & MINJ' & INJINCR & INJSEP).
    set (rs' := nextinstr_nf (set_res res vres2 (undef_regs (map preg_of (Machregs.destroyed_by_builtin ef)) rs'0)) (sect_block_size pbsect)).
    exploit (FlatAsm.exec_step_builtin tge (Ptrofs.add ofs (Ptrofs.repr delta))
                                       ef x0 res rs'0  m'0 vargs' t vres2 rs' m2' pbsect); auto.
    unfold valid_instr_offset_is_internal in INSTRINTERNAL.
    eapply INSTRINTERNAL; eauto.
    intros FSTEP. eexists; split; eauto.
    eapply match_states_intro with (j:=j'); eauto.
    (* Supposely the following propreties can proved by separation property of injections *)
    + eapply (inject_pres_match_sminj j); eauto.
    + eapply (inject_pres_globs_inj_into_flatmem j); eauto.
    + eapply (inject_pres_valid_instr_offset_is_internal j); eauto.
    + eapply (inject_pres_extfun_entry_is_external j); eauto.
    + eapply (inject_pres_match_find_funct j); eauto.
    + subst rs'. unfold regset_inject. intros. subst pbsect; simpl.
      unfold nextinstr_nf, Asm.nextinstr_nf.
      assert (regset_inject j' rs rs'0) by 
          (eapply regset_inject_incr; eauto).
      set (dregs := (map Asm.preg_of (Machregs.destroyed_by_builtin ef))) in *.
      unfold preg_of. fold dregs.
      generalize (undef_regs_pres_inject j' rs rs'0 dregs H5). intros.
      unfold undef_regs. unfold set_res.
      set (rs1 := (Asm.undef_regs dregs rs)) in *.
      set (rs2 := (Asm.undef_regs dregs rs'0)) in *.
      generalize (set_res_pres_inject res j' 
                  rs1 rs2 H9 vres vres2 RESINJ).
      set (rs3 := (Asm.set_res res vres rs1)) in *.
      set (rs4 := (Asm.set_res res vres2 rs2)) in *.
      intros.
      fold ZF CF PF SF OF.
      set (fregs := (CR ZF :: CR CF :: CR PF :: CR SF :: CR OF :: nil)) in *.
      generalize (undef_regs_pres_inject j' rs3 rs4 fregs H10).
      intros.         
      generalize (nextinstr_pres_inject j'  
                    (undef_regs fregs rs3) (undef_regs fregs rs4) 
                    (Ptrofs.repr (si_size sz)) H11).
      intros. unfold regset_inject in H12.
      apply H12.
    + eapply extcall_pres_glob_block_valid; eauto.

  - (* External call *)
    unfold regset_inject in RSINJ. generalize (RSINJ Asm.PC). rewrite H. 
    inversion 1; subst. rewrite Ptrofs.add_zero_l in H6.
    exploit (globs_to_funs_inj_into_flatmem j); eauto. inversion 1; subst.
    generalize (extcall_arguments_inject rs rs'0 m m'0 ef args j H1 MINJ RSINJ).
    intros (args2 & ARGSINJ & EXTCALLARGS).
    exploit (external_call_inject j args args2 m m'0 m' res t ef); eauto.
    intros (j' & res' & m2' & EXTCALL & RESINJ & MINJ' & INJINCR & INJSEP).
    exploit (FlatAsm.exec_step_external tge (Ptrofs.repr delta) ef args2 res'); eauto.
    + generalize (RSINJ Asm.RSP). intros. 
      eapply vinject_pres_has_type; eauto.
    + generalize (RSINJ Asm.RA). intros. 
      eapply vinject_pres_has_type; eauto.
    + generalize (RSINJ Asm.RSP). intros. 
      eapply vinject_pres_not_vundef; eauto.
    + generalize (RSINJ Asm.RA). intros. 
      eapply vinject_pres_not_vundef; eauto.
    + intros FSTEP. eexists. split. apply FSTEP.
      eapply match_states_intro with (j := j'); eauto.
      * eapply (inject_pres_match_sminj j); eauto.
      * eapply (inject_pres_globs_inj_into_flatmem j); eauto.
      * eapply (inject_pres_valid_instr_offset_is_internal j); eauto.
      * eapply (inject_pres_extfun_entry_is_external j); eauto.
      * eapply (inject_pres_match_find_funct j); eauto.
      * assert (regset_inject j' rs rs'0) by 
            (eapply regset_inject_incr; eauto).
        unfold preg_of. 
        set (dregs := (map Asm.preg_of Conventions1.destroyed_at_call)) in *.
        generalize (undef_regs_pres_inject j' rs rs'0 dregs H4). intros.
        unfold undef_regs. unfold ZF, CF, PF, SF, OF.
        set (rs1 := (Asm.undef_regs dregs rs)) in *.
        set (rs2 := (Asm.undef_regs dregs rs'0)) in *.
        set (cdregs := (CR Asm.ZF :: CR Asm.CF :: CR Asm.PF :: CR Asm.SF :: CR Asm.OF :: nil)) in *.
        generalize (undef_regs_pres_inject j' rs1 rs2 cdregs H8). intros.
        set (rs3 := (Asm.undef_regs cdregs rs1)) in *.
        set (rs4 := (Asm.undef_regs cdregs rs2)) in *.
        generalize (set_pair_pres_inject j' rs3 rs4 res res' 
                                         (Asm.loc_external_result (ef_sig ef))
                                         H9 RESINJ).
        intros.
        apply regset_inject_expand; auto.
        apply regset_inject_expand; auto.
    * eapply extcall_pres_glob_block_valid; eauto.
Qed.        

End PRESERVATION.

End WITHMEMORYMODEL.