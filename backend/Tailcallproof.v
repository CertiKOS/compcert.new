(* *********************************************************************)
(*                                                                     *)
(*              The Compcert verified compiler                         *)
(*                                                                     *)
(*          Xavier Leroy, INRIA Paris-Rocquencourt                     *)
(*                                                                     *)
(*  Copyright Institut National de Recherche en Informatique et en     *)
(*  Automatique.  All rights reserved.  This file is distributed       *)
(*  under the terms of the INRIA Non-Commercial License Agreement.     *)
(*                                                                     *)
(* *********************************************************************)

(** Recognition of tail calls: correctness proof *)

Require Import Coqlib Maps Integers AST Linking.
Require Import Values Memory Events Globalenvs Smallstep.
Require Import Op Registers RTL Conventions Tailcall.

(** * Syntactic properties of the code transformation *)

(** ** Measuring the number of instructions eliminated *)

(** The [return_measure c pc] function counts the number of instructions
  eliminated by the code transformation, where [pc] is the successor
  of a call turned into a tailcall.  This is the length of the
  move/nop/return sequence recognized by the [is_return] boolean function.
*)

Fixpoint return_measure_rec (n: nat) (c: code) (pc: node)
                            {struct n}: nat :=
  match n with
  | O => O
  | S n' =>
      match c!pc with
      | Some(Inop s) => S(return_measure_rec n' c s)
      | Some(Iop op args dst s) => S(return_measure_rec n' c s)
      | _ => O
      end
  end.

Definition return_measure (c: code) (pc: node) :=
  return_measure_rec niter c pc.

Lemma return_measure_bounds:
  forall f pc, (return_measure f pc <= niter)%nat.
Proof.
  intro f.
  assert (forall n pc, (return_measure_rec n f pc <= n)%nat).
    induction n; intros; simpl.
    omega.
    destruct (f!pc); try omega.
    destruct i; try omega.
    generalize (IHn n0). omega.
    generalize (IHn n0). omega.
  intros. unfold return_measure. apply H.
Qed.

Remark return_measure_rec_incr:
  forall f n1 n2 pc,
  (n1 <= n2)%nat ->
  (return_measure_rec n1 f pc <= return_measure_rec n2 f pc)%nat.
Proof.
  induction n1; intros; simpl.
  omega.
  destruct n2. omegaContradiction. assert (n1 <= n2)%nat by omega.
  simpl. destruct f!pc; try omega. destruct i; try omega.
  generalize (IHn1 n2 n H0). omega.
  generalize (IHn1 n2 n H0). omega.
Qed.

Lemma is_return_measure_rec:
  forall f n n' pc r,
  is_return n f pc r = true -> (n <= n')%nat ->
  return_measure_rec n f.(fn_code) pc = return_measure_rec n' f.(fn_code) pc.
Proof.
  induction n; simpl; intros.
  congruence.
  destruct n'. omegaContradiction. simpl.
  destruct (fn_code f)!pc; try congruence.
  destruct i; try congruence.
  decEq. apply IHn with r. auto. omega.
  destruct (is_move_operation o l); try congruence.
  destruct (Reg.eq r r1); try congruence.
  decEq. apply IHn with r0. auto. omega.
Qed.

(** ** Relational characterization of the code transformation *)

(** The [is_return_spec] characterizes the instruction sequences
  recognized by the [is_return] boolean function.  *)

Inductive is_return_spec (f:function): node -> reg -> Prop :=
  | is_return_none: forall pc r,
      f.(fn_code)!pc = Some(Ireturn None) ->
      is_return_spec f pc r
  | is_return_some: forall pc r,
      f.(fn_code)!pc = Some(Ireturn (Some r)) ->
      is_return_spec f pc r
  | is_return_nop: forall pc r s,
      f.(fn_code)!pc = Some(Inop s) ->
      is_return_spec f s r ->
      (return_measure f.(fn_code) s < return_measure f.(fn_code) pc)%nat ->
      is_return_spec f pc r
  | is_return_move: forall pc r r' s,
      f.(fn_code)!pc = Some(Iop Omove (r::nil) r' s) ->
      is_return_spec f s r' ->
      (return_measure f.(fn_code) s < return_measure f.(fn_code) pc)%nat ->
     is_return_spec f pc r.

Lemma is_return_charact:
  forall f n pc rret,
  is_return n f pc rret = true -> (n <= niter)%nat ->
  is_return_spec f pc rret.
Proof.
  induction n; intros.
  simpl in H. congruence.
  generalize H. simpl.
  caseEq ((fn_code f)!pc); try congruence.
  intro i. caseEq i; try congruence.
  intros s; intros. eapply is_return_nop; eauto. eapply IHn; eauto. omega.
  unfold return_measure.
  rewrite <- (is_return_measure_rec f (S n) niter pc rret); auto.
  rewrite <- (is_return_measure_rec f n niter s rret); auto.
  simpl. rewrite H2. omega. omega.

  intros op args dst s EQ1 EQ2.
  caseEq (is_move_operation op args); try congruence.
  intros src IMO. destruct (Reg.eq rret src); try congruence.
  subst rret. intro.
  exploit is_move_operation_correct; eauto. intros [A B]. subst.
  eapply is_return_move; eauto. eapply IHn; eauto. omega.
  unfold return_measure.
  rewrite <- (is_return_measure_rec f (S n) niter pc src); auto.
  rewrite <- (is_return_measure_rec f n niter s dst); auto.
  simpl. rewrite EQ2. omega. omega.

  intros or EQ1 EQ2. destruct or; intros.
  assert (r = rret). eapply proj_sumbool_true; eauto. subst r.
  apply is_return_some; auto.
  apply is_return_none; auto.
Qed.

(** The [transf_instr_spec] predicate relates one instruction in the
  initial code with its possible transformations in the optimized code. *)

Inductive transf_instr_spec (f: function): instruction -> instruction -> Prop :=
  | transf_instr_tailcall: forall sig ros args res s,
      f.(fn_stacksize) = 0 ->
      is_return_spec f s res ->
      transf_instr_spec f (Icall sig ros args res s) (Itailcall sig ros args)
  | transf_instr_default: forall i,
      transf_instr_spec f i i.

Lemma transf_instr_charact:
  forall f pc instr,
  f.(fn_stacksize) = 0 ->
  transf_instr_spec f instr (transf_instr f pc instr).
Proof.
  intros. unfold transf_instr. destruct instr; try constructor.
  caseEq (is_return niter f n r && tailcall_is_possible s &&
          opt_typ_eq (sig_res s) (sig_res (fn_sig f))); intros.
  destruct (andb_prop _ _ H0). destruct (andb_prop _ _ H1).
  eapply transf_instr_tailcall; eauto.
  eapply is_return_charact; eauto.
  constructor.
Qed.

Lemma transf_instr_lookup:
  forall f pc i,
  f.(fn_code)!pc = Some i ->
  exists i',  (transf_function f).(fn_code)!pc = Some i' /\ transf_instr_spec f i i'.
Proof.
  intros. unfold transf_function.
  destruct (zeq (fn_stacksize f) 0).
  simpl. rewrite PTree.gmap. rewrite H. simpl.
  exists (transf_instr f pc i); split. auto. apply transf_instr_charact; auto.
  exists i; split. auto. constructor.
Qed.

(** * Semantic properties of the code transformation *)

(** ** The ``less defined than'' relation between register states *)

(** A call followed by a return without an argument can be turned
  into a tail call.  In this case, the original function returns
  [Vundef], while the transformed function can return any value.
  We account for this situation by using the ``less defined than''
  relation between values and between memory states.  We need to
  extend it pointwise to register states. *)

Lemma regs_lessdef_init_regs:
  forall params vl vl',
  Val.lessdef_list vl vl' ->
  regs_lessdef (init_regs vl params) (init_regs vl' params).
Proof.
  induction params; intros.
  simpl. red; intros. rewrite Regmap.gi. constructor.
  simpl. inv H.   red; intros. rewrite Regmap.gi. constructor.
  apply set_reg_lessdef. auto. auto.
Qed.

(** * Proof of semantic preservation *)

Definition match_prog (p tp: RTL.program) :=
  match_program (fun cu f tf => tf = transf_fundef f) eq p tp.

Lemma transf_program_match:
  forall p, match_prog p (transf_program p).
Proof.
  intros. apply match_transform_program; auto.
Qed.

Section PRESERVATION.
Context `{external_calls_prf: ExternalCalls}.

Existing Instance inject_perm_all.

Variable prog tprog: program.
Hypothesis TRANSL: match_prog prog tprog.

Definition regs_inject (j: meminj) (rs1 rs2: Regmap.t val) :=
  forall r,
    Val.inject j (rs1 # r) (rs2 # r).

Definition inject_globals  {F V} (g: Genv.t F V) j:=
  (forall b,
      Plt b (Genv.genv_next g) -> j b = Some (b,0)) /\
  (forall b1 b2 delta,
      j b1 = Some (b2, delta) -> Plt b2 (Genv.genv_next g) -> b2 = b1 /\ delta = 0).

Let ge := Genv.globalenv prog.
Let tge := Genv.globalenv tprog.

Lemma symbols_preserved:
  forall (s: ident), Genv.find_symbol tge s = Genv.find_symbol ge s.
Proof (Genv.find_symbol_transf TRANSL).

Lemma functions_translated:
  forall (v: val) (f: RTL.fundef),
  Genv.find_funct ge v = Some f ->
  Genv.find_funct tge v = Some (transf_fundef f).
Proof (Genv.find_funct_transf TRANSL).

Lemma funct_ptr_translated:
  forall (b: block) (f: RTL.fundef),
  Genv.find_funct_ptr ge b = Some f ->
  Genv.find_funct_ptr tge b = Some (transf_fundef f).
Proof (Genv.find_funct_ptr_transf TRANSL).

Lemma senv_preserved:
  Senv.equiv ge tge.
Proof (Genv.senv_transf TRANSL).

Lemma genv_next_preserved:
  Genv.genv_next tge = Genv.genv_next ge.
Proof.
  apply senv_preserved.
Qed.

Lemma sig_preserved:
  forall f, funsig (transf_fundef f) = funsig f.
Proof.
  destruct f; auto. simpl. unfold transf_function.
  destruct (zeq (fn_stacksize f) 0); auto.
Qed.

Lemma stacksize_preserved:
  forall f, fn_stacksize (transf_function f) = fn_stacksize f.
Proof.
  unfold transf_function. intros.
  destruct (zeq (fn_stacksize f) 0); auto.
Qed.

Lemma find_function_translated:
  forall ros rs rs' f j,
  find_function ge ros rs = Some f ->
  regs_inject j rs rs' ->
  inject_globals ge j ->
  find_function tge ros rs' = Some (transf_fundef f).
Proof.
  intros ros rs rs' f j FF RI IG; destruct ros; simpl in *.
  assert (rs'#r = rs#r).
  {
    exploit Genv.find_funct_inv; eauto. intros [b EQ].
    generalize (RI r). rewrite EQ. intro LD. inv LD.
    rewrite EQ in FF.
    unfold Genv.find_funct in FF; repeat destr_in FF.
    unfold Genv.find_funct_ptr in H0. repeat destr_in H0.
    eapply Genv.genv_defs_range in Heqo.
    destruct IG as (IG1 & IG2).
    erewrite IG1 in H2; eauto. inv H2. reflexivity.
  } 
  rewrite H. apply functions_translated; auto.
  rewrite symbols_preserved. destruct (Genv.find_symbol ge i); intros.
  apply funct_ptr_translated; auto.
  discriminate.
Qed.

(** Consider an execution of a call/move/nop/return sequence in the
  original code and the corresponding tailcall in the transformed code.
  The transition sequences are of the following form
  (left: original code, right: transformed code).
  [f] is the calling function and [fd] the called function.
<<
     State stk f (Icall instruction)       State stk' f' (Itailcall)

     Callstate (frame::stk) fd args        Callstate stk' fd' args'
            .                                       .
            .                                       .
            .                                       .
     Returnstate (frame::stk) res          Returnstate stk' res'

     State stk f (move/nop/return seq)
            .
            .
            .
     State stk f (return instr)

     Returnstate stk res
>>
The simulation invariant must therefore account for two kinds of
mismatches between the transition sequences:
- The call stack of the original program can contain more frames
  than that of the transformed program (e.g. [frame] in the example above).
- The regular states corresponding to executing the move/nop/return
  sequence must all correspond to the single [Returnstate stk' res']
  state of the transformed program.

We first define the simulation invariant between call stacks.
The first two cases are standard, but the third case corresponds
to a frame that was eliminated by the transformation. *)

(* The list of boolean records whether the source frame has a corresponding
counterpart in the target stack ([true]) or not ([false]). This will later be used
to specify the shape of the stack injection function [g]. *)
Inductive match_stackframes: meminj -> list stackframe -> list stackframe -> Prop :=
  | match_stackframes_nil j:
      match_stackframes j nil nil
  | match_stackframes_normal: forall j stk stk' res sp sp' pc rs rs' f tc,
      match_stackframes j stk stk' ->
      regs_inject j rs rs' ->
      j sp = Some (sp',0) ->
      match_stackframes j 
        (Stackframe res f false (Vptr sp Ptrofs.zero) pc rs :: stk)
        (Stackframe res (transf_function f) tc (Vptr sp' Ptrofs.zero) pc rs' :: stk')
  | match_stackframes_tail: forall j stk stk' res sp pc rs f tc,
      match_stackframes j stk stk' ->
      is_return_spec f pc res ->
      f.(fn_stacksize) = 0 ->
      match_stackframes j
        (Stackframe res f false (Vptr sp Ptrofs.zero) pc rs :: stk)
        (StackframeTailcalled tc :: stk')
.

(* Specifying the shape of stack injection functions *)

(* [compat_frameinj_rec l g ns nt]
   [ns] is the stage position in the source stack, [nt] in the target stack.
   [l] is the target call stack.
   [g] is compatible with [l] if the corresponding frames are injected correctly by [g].
   Tailcalled stack frames are injected into the current target stage and we do
   not increment the target stage.
 *)

Definition tc_of_stackframe sf :=
  match sf with | Stackframe _ _ tc _ _ _ => tc | StackframeTailcalled tc => tc end.

Fixpoint compat_frameinj_rec (l: list bool) (g: frameinj) (ns nt: nat) :=
  match l with
    nil => forall i j (LE: (ns <= i)%nat) (Gi: g i = Some j), (nt <= j)%nat
  | tc :: l =>
    g ns = Some nt /\ compat_frameinj_rec l g (S ns) (if tc then nt else S nt)
  end.

Definition compat_frameinj l g := compat_frameinj_rec l g O O.

Lemma compat_frameinj_rec_above:
  forall l g ns nt (CFG: compat_frameinj_rec l g ns nt)
    i j (Gi: g i = Some j) (LE: (ns <= i)%nat),
    (nt <= j)%nat.
Proof.
  induction l; simpl; intros; eauto.
  destruct CFG as (GNS & GABOVE).
  destruct (Nat.eq_dec ns i); subst; auto.
  rewrite GNS in Gi; inv Gi; auto.
  eapply IHl in GABOVE. 2: apply Gi. 2: omega.
  destruct a; omega.
Qed.

(** Here is the invariant relating two states.  The first three
  cases are standard.  Note the ``less defined than'' conditions
  over values and register states, and the corresponding ``extends''
  relation over memory states. *)

Inductive match_states: state -> state -> Prop :=
  | match_states_normal:
      forall s sp sp' pc rs m s' rs' m' f g j tc
             (STACKS: match_stackframes j s s')
             (RLD: regs_inject j rs rs')
             (MLD: Mem.inject j g m m')
             (CFG: compat_frameinj (tc::map tc_of_stackframe s') g)
             (IG: inject_globals ge j)
             (JB: j sp = Some (sp', 0)),
      match_states (State s f false (Vptr sp Ptrofs.zero) pc rs m)
                   (State s' (transf_function f) tc (Vptr sp' Ptrofs.zero) pc rs' m')
  | match_states_call:
      forall s f args m s' args' m' sz g j (tc1 tc2: bool)
        (MS: match_stackframes j s s')
        (LDargs: Val.inject_list j args args')
        (MLD: Mem.inject j g m m')
        (CFG: compat_frameinj (map tc_of_stackframe s') g)
        (IG: inject_globals ge j),
      match_states (Callstate s f args m sz tc1)
                   (Callstate s' (transf_fundef f) args' m' sz tc2)
  | match_states_return:
      forall s v m s' v' m' g j
        (MS: match_stackframes j s s')
        (LDret: Val.inject j v v')
        (MLD: Mem.inject j g m m')
        (CFG: compat_frameinj (map tc_of_stackframe s') g)
             (IG: inject_globals ge j),
        match_states (Returnstate s v m)
                     (Returnstate s' v' m')
  | match_states_interm:
      forall s sp pc rs m s' m' f r v' g j
             (STACKS: match_stackframes j s s')
             (MLD: Mem.inject j g m m')
             (RETspec: is_return_spec f pc r)
             (SZzero: f.(fn_stacksize) = 0)
             (LDret: Val.inject j (rs#r) v')
             (CFG: compat_frameinj (false::map tc_of_stackframe s') g)
             (IG: inject_globals ge j),
        match_states (State s f false (Vptr sp Ptrofs.zero) pc rs m)
                     (Returnstate s' v' m').

Definition mem_state (s: state) : mem :=
  match s with
    State _ _ _ _ _ _ m
  | Callstate _ _ _ m _ _
  | Returnstate _ _ m => m
  end.

Definition match_state_ge {F V} (g: Genv.t F V) (s: state) :=
  Ple (Genv.genv_next g) (Mem.nextblock (mem_state s)).

Definition current_sp_state (s: state) : option (option (block * Z)) :=
  match s with
    State _ f _ (Vptr sp _) _ _ _ => Some (Some (sp, fn_stacksize f))
  | State _ _ _ _ _ _ _ => None
  | _ => Some None
  end.

Definition stackblocks_of_stackframe (sf: stackframe) : option (block * Z) :=
  match sf with
  | (Stackframe _ f _ (Vptr sp _) _ _) => Some (sp,fn_stacksize f)
  | _ => None
  end.

Definition stackframes_state (s: state) : list stackframe :=
  match s with
    State stk _ _ _ _ _ _
  | Callstate stk _ _ _ _ _
  | Returnstate stk _ _ => stk
  end.

Definition stack_blocks_of_state (s: state) : list (option (block * Z)) :=
  match current_sp_state s with
    Some (Some x) => Some x :: map stackblocks_of_stackframe (stackframes_state s)
  | Some None => map stackblocks_of_stackframe (stackframes_state s)
  | None => None :: map stackblocks_of_stackframe (stackframes_state s)
  end.

Definition sp_valid (s : state) : Prop :=
  Forall (fun bz => match bz with
                   Some (b,z) => Mem.valid_block (mem_state s) b
                 | None => True
                 end) (stack_blocks_of_state s).

Definition match_stack_adt (s: state) :=
  let stk := Mem.stack_adt (mem_state s) in
  let sbl := stack_blocks_of_state s in
  exists sprog sinit,
    stk = sprog ++ sinit /\
    list_forall2 (fun (fl: tframe_adt) obz =>
                    match obz with
                      Some (b,z) =>
                      (exists f, hd_error fl = Some f /\ map fst (frame_adt_blocks f) = b :: nil) /\
                      forall o k p,
                        Mem.perm (mem_state s) b o k p ->
                        0 <= o < z
                    | None => False
                    end
                 ) sprog sbl.

(** The last case of [match_states] corresponds to the execution
  of a move/nop/return sequence in the original code that was
  eliminated by the transformation:
<<
     State stk f (move/nop/return seq)  ~~  Returnstate stk' res'
            .
            .
            .
     State stk f (return instr)         ~~  Returnstate stk' res'
>>
  To preserve non-terminating behaviors, we need to make sure
  that the execution of this sequence in the original code cannot
  diverge.  For this, we introduce the following complicated
  measure over states, which will decrease strictly whenever
  the original code makes a transition but the transformed code
  does not. *)

Definition measure (st: state) : nat :=
  match st with
  | State s f tc sp pc rs m => (List.length s * (niter + 2) + return_measure f.(fn_code) pc + 1)%nat
  | Callstate s f args m sz tc => 0%nat
  | Returnstate s v m => (List.length s * (niter + 2))%nat
  end.

Ltac TransfInstr :=
  match goal with
  | H: (PTree.get _ (fn_code _) = _) |- _ =>
      destruct (transf_instr_lookup _ _ _ H) as [i' [TINSTR TSPEC]]; inv TSPEC
  end.

Ltac EliminatedInstr :=
  match goal with
  | H: (is_return_spec _ _ _) |- _ => inv H; try congruence
  | _ => idtac
  end.

(** The proof of semantic preservation, then, is a simulation diagram
  of the ``option'' kind. *)


Lemma regs_inject_regs:
  forall j rs1 rs2, regs_inject j rs1 rs2 ->
  forall rl, Val.inject_list j rs1##rl rs2##rl.
Proof.
  induction rl; constructor; auto.
Qed.

Lemma set_reg_inject:
  forall j r v1 v2 rs1 rs2,
  Val.inject j v1 v2 -> regs_inject j rs1 rs2 -> regs_inject j (rs1#r <- v1) (rs2#r <- v2).
Proof.
  intros; red; intros. repeat rewrite Regmap.gsspec.
  destruct (peq r0 r); auto.
Qed.

Lemma set_res_inject:
  forall j res v1 v2 rs1 rs2,
  Val.inject j v1 v2 -> regs_inject j rs1 rs2 ->
  regs_inject j (regmap_setres res v1 rs1) (regmap_setres res v2 rs2).
Proof.
  intros. destruct res; simpl; auto. apply set_reg_inject; auto.
Qed.





Variable fn_stack_requirements: ident -> Z.


Lemma ros_is_function_transf:
  forall j ros rs rs' id,
    inject_globals ge j ->
    ros_is_function ge ros rs id ->
    regs_inject j rs rs' ->
    ros_is_function tge ros rs' id.
Proof.
  unfold ros_is_function. intros.
  destr_in H0. simpl.
  destruct H0 as (b & o & RS & FS).
  specialize (H1 r). rewrite RS in H1; inv H1.
  eexists; eexists; split; eauto.
  rewrite symbols_preserved. rewrite FS.
  f_equal.
  destruct H. erewrite H in H4. inv H4. auto. 
  eapply Genv.genv_symb_range; eauto.
Qed.

Lemma inject_globals_meminj_preserves_globals:
  forall {F V} (g: Genv.t F V) j,
    inject_globals g j ->
    meminj_preserves_globals g j.
Proof.
  intros F V g j (IG1 & IG2); split; [|split].
  - intros id b FS.
    eapply IG1. eapply Genv.genv_symb_range; eauto.
  - intros b gv FVI.
    unfold Genv.find_var_info in FVI.
    repeat destr_in FVI.
    eapply IG1. eapply Genv.genv_defs_range; eauto.
  - intros b1 b2 delta gv FVI JB.
    unfold Genv.find_var_info in FVI.
    repeat destr_in FVI.
    eapply IG2 in JB; eauto. apply JB. eapply Genv.genv_defs_range; eauto.
Qed.


Lemma compat_frameinj_rec_pop_left:
  forall g l ns nt
    (CF: compat_frameinj_rec l g (S ns) nt),
    compat_frameinj_rec l (fun n : nat => g (S n)) ns nt.
Proof.
  induction l; simpl; intros; eauto.
  - eapply CF in Gi; eauto. omega.
  - destruct a; destruct CF as [Gn CF].
    + split; auto.
    + split; auto.
Qed.


Lemma regs_inject_init_regs:
  forall j params vl vl',
    Val.inject_list j vl vl' ->
    regs_inject j (init_regs vl params) (init_regs vl' params).
Proof.
  induction params; intros.
  simpl. red; intros. rewrite Regmap.gi. constructor.
  simpl. inv H.   red; intros. rewrite Regmap.gi. constructor.
  apply set_reg_inject. auto. auto.
Qed.
Lemma compat_frameinj_rec_push_parallel:
  forall g l ns nt
    (CFR: compat_frameinj_rec l g ns nt)
    g'
    (G'spec: forall i, (S ns <= i)%nat -> g' i = option_map S (g (pred i))),
    compat_frameinj_rec l g' (S ns) (S nt).
Proof.
  induction l; simpl; intros; eauto.
  - rewrite G'spec in Gi; auto.
    unfold option_map in Gi; repeat destr_in Gi.
    eapply CFR in Heqo. omega. omega. 
  - destr; destruct CFR as (Gn & CFR).
    + split.
      * rewrite G'spec; auto.
        unfold option_map. simpl. rewrite Gn. reflexivity.
      * eapply IHl; eauto.
        intros; apply G'spec. omega.
    + split.
      * rewrite G'spec; auto.
        unfold option_map. simpl. rewrite Gn. reflexivity.
      * eapply IHl; eauto.
        intros; apply G'spec. omega.
Qed.


Lemma compat_frameinj_pop_right_rec:
  forall g l ns nt
    (CFR: compat_frameinj_rec l g ns (S nt))
    g' (G'spec: forall i, (ns <= i)%nat -> g' i = option_map pred (g i)),
    compat_frameinj_rec l g' ns nt.
Proof.
  induction l; simpl; intros; eauto.
  - rewrite G'spec in Gi; auto.
    unfold option_map in Gi; repeat destr_in Gi.
    eapply CFR in Heqo. omega. auto.
  - destr; destruct CFR as (Gn & CFR).
    + split.
      * rewrite G'spec; auto.
        unfold option_map. rewrite Gn. reflexivity.
      * eapply IHl; eauto.
        intros; apply G'spec. omega.
    + split.
      * rewrite G'spec; auto.
        unfold option_map. rewrite Gn. reflexivity.
      * eapply IHl; eauto.
        intros; apply G'spec. omega.
Qed.

Lemma compat_frameinj_pop_right:
  forall g l,
    compat_frameinj (false :: l) g ->
    compat_frameinj (true :: l) (fun n : nat => if Nat.eq_dec n 0 then Some O else option_map Init.Nat.pred (g n)).
Proof.
  intros g l (A & B); split; simpl; auto.
  eapply compat_frameinj_pop_right_rec; eauto.
  intros. destr. omega.
Qed.

Lemma compat_frameinj_rec_pop_parallel:
  forall g l ns nt
    (CFR: compat_frameinj_rec l g (S ns) (S nt)),
    compat_frameinj_rec l (down g) ns nt.
Proof.
  unfold down, downstar.
  induction l; simpl; intros; eauto.
  - unfold option_map in Gi; repeat destr_in Gi.
    eapply CFR in Heqo. omega. omega.
  - destruct CFR as (Gn & CFR).
    split.
    unfold option_map. rewrite Gn. reflexivity.
    eapply IHl; eauto.
    destruct a; auto.
Qed.

Lemma match_stackframes_incr:
  forall f s s'
    (MS: match_stackframes f s s')
    f' (INCR: inject_incr f f'),
    match_stackframes f' s s'.
Proof.
  induction 1; simpl; intros; eauto; try now econstructor; eauto.
  econstructor; eauto.
  red; intros; eauto.
Qed.

Lemma inject_globals_incr:
  forall f f'
    (INCR : inject_incr f f')
    (SEP : forall b1 b2 delta, f b1 = None -> f' b1 = Some (b2, delta) -> Ple (Genv.genv_next ge) b1 /\ Ple (Genv.genv_next ge) b2)
    (IG: inject_globals ge f),
    inject_globals ge f'.
Proof.
  intros f f' INCR SEP (IG1 & IG2); split; intros; eauto.
  eapply IG2; eauto.
  destruct (f b1) eqn:FB1.
  - destruct p. eapply INCR in FB1. congruence.
  - specialize (SEP _ _ _ FB1 H).
    xomega.
Qed.


Lemma transf_step_correct:
  forall s1 t s2, step fn_stack_requirements ge s1 t s2 ->
  forall s1' (MS: match_states s1 s1') (MSG: match_state_ge ge s1) (MSG': match_state_ge tge s1') (SPV: sp_valid s1) (MSA: match_stack_adt s1) (MSA': match_stack_adt s1'),
  (exists s2', step fn_stack_requirements tge s1' t s2' /\ match_states s2 s2')
  \/ (measure s2 < measure s1 /\ t = E0 /\ match_states s2 s1')%nat.
Proof.
  induction 1; intros; inv MS; EliminatedInstr.

- (* nop *)
  TransfInstr. left. econstructor; split.
  eapply exec_Inop; eauto. econstructor; eauto.
- (* eliminated nop *)
  assert (s0 = pc') by congruence. subst s0.
  right. split. simpl. omega. split. auto.
  econstructor; eauto.

- (* op *)
  TransfInstr.
  assert (Val.inject_list j (rs##args) (rs'##args)). apply regs_inject_regs; auto.
  exploit eval_operation_inject; eauto.
  eapply inject_globals_meminj_preserves_globals; eauto.
  intros [v' [EVAL' VLD]].
  left. exists (State s' (transf_function f) tc0 (Vptr sp' Ptrofs.zero) pc' (rs'#res <- v') m'); split.
  eapply exec_Iop; eauto.  rewrite <- EVAL'.
  rewrite eval_shift_stack_operation.
  apply eval_operation_preserved. exact symbols_preserved.
  econstructor; eauto. apply set_reg_inject; auto.
- (* eliminated move *)
  rewrite H1 in H. clear H1. inv H.
  right. split. simpl. omega. split. auto.
  econstructor; eauto. simpl in H0. rewrite PMap.gss. congruence.

- (* load *)
  TransfInstr.
  assert (Val.inject_list j (rs##args) (rs'##args)). apply regs_inject_regs; auto.
  exploit eval_addressing_inject; eauto.
  eapply inject_globals_meminj_preserves_globals; eauto.
  intros [a' [ADDR' ALD]].
  exploit Mem.loadv_inject; eauto.
  intros [v' [LOAD' VLD]].
  left. exists (State s' (transf_function f) tc0 (Vptr sp' Ptrofs.zero) pc' (rs'#dst <- v') m'); split.
  eapply exec_Iload with (a0 := a'). eauto.  rewrite <- ADDR'.
  rewrite eval_shift_stack_addressing.
  apply eval_addressing_preserved. exact symbols_preserved. eauto.
  econstructor; eauto. apply set_reg_inject; auto.

- (* store *)
  TransfInstr.
  assert (Val.inject_list j (rs##args) (rs'##args)). apply regs_inject_regs; auto.
  exploit eval_addressing_inject; eauto.
  eapply inject_globals_meminj_preserves_globals; eauto.
  intros [a' [ADDR' ALD]].
  exploit Mem.storev_mapped_inject. 2: eexact H1. eauto. eauto. apply RLD.
  intros [m'1 [STORE' MLD']].
  left. exists (State s' (transf_function f) tc0 (Vptr sp' Ptrofs.zero) pc' rs' m'1); split.
  eapply exec_Istore with (a0 := a'). eauto.  rewrite <- ADDR'.
  rewrite eval_shift_stack_addressing.
  apply eval_addressing_preserved. exact symbols_preserved. eauto.
  destruct a; simpl in H1; try discriminate.
  econstructor; eauto.

- (* call *)
  exploit find_function_translated; eauto. intro FIND'.
  TransfInstr.
+ (* call turned tailcall *)
  assert (X: { m'' | Mem.free m' sp' 0 (fn_stacksize (transf_function f)) = Some m''}).
  {
    apply Mem.range_perm_free. rewrite stacksize_preserved. rewrite H7.
    red; intros; omegaContradiction.
  } 
  destruct X as [m'' FREE].
  generalize (Mem.free_right_inject _ _ _ _ _ _ _ _ MLD FREE). intro FINJ.
  trim FINJ.
  {
    unfold Mem.flat_inj.
    intros b1 delta ofs k p FI PERM RNG.
    repeat destr_in FI.
    rewrite stacksize_preserved in RNG. rewrite H7 in RNG. omega.
  }
  (* destruct MSA as (sprog & sinit & EQstk & LF2). *)
  (* inv LF2. simpl in EQstk. *)
  (* destruct MSA' as (sprog' & sinit' & EQstk' & LF2'). *)
  (* inv LF2'. simpl in EQstk'. *)
  (* edestruct (Mem.unrecord_stack_block_succeeds m'') as (m2' & USB & EQ). *)
  (* erewrite Mem.free_stack_blocks; eauto. *)
  (* generalize (Mem.unrecord_stack_block_inject_right _ _ _ _ m2' FINJ). intro UINJ. *)
  (* trim UINJ. *)
  (* { *)
  (*   rewrite EQstk. unfold is_stack_top. simpl. *)
  (*   destruct H4 as ((ff & INF & frame_blocks) & perm_stack). *)
  (*   destruct a1. easy. unfold get_frames_blocks. setoid_rewrite concat_In. inv INF. *)
  (*   simpl. intros b (x & IN & [A|A]). subst. *)
  (*   unfold get_frame_blocks in IN. rewrite frame_blocks in IN. destruct IN as [EQsp|[]]. subst. *)
  (*   intros (o & k & p & PERM). *)
  (*   apply perm_stack in PERM. rewrite H7 in PERM. omega. *)
  (*   intros (o & k & p & PERM). *)

  (*   Axiom mem_wf_stack: *)
  (*     forall m, wf_stack (Mem.perm m) inject_id (Mem.stack_adt m). *)
  (*   generalize (mem_wf_stack m). rewrite EQstk. simpl. inversion 1. *)
  (*   red in H4. simpl in H4. *)
  (*   eapply H4; eauto. unfold inject_id; congruence. *)
  (*   apply in_map_iff in A. destruct A as (xx0 & EQfb & INx0). *)
  (*   subst. eapply in_frame_in_frames; eauto.  *)

  (* } *)
  (* trim UINJ. *)
  (* { *)
  (*   red in CFG. simpl in CFG. *)
  (*   intros i1 i2 Gi LT. *)
  (*   eapply compat_frameinj_rec_above in Gi. 2: apply CFG. omega. omega. *)
  (* } *)
  (* trim UINJ. apply CFG. *)
  (* trim UINJ. eauto. *)
  left. eexists (Callstate (StackframeTailcalled tc0 ::s') (transf_fundef fd) (rs'##args) m'' (fn_stack_requirements id) true); split.
  eapply exec_Itailcall; eauto.
  eapply ros_is_function_transf; eauto.
  apply sig_preserved.
  econstructor; eauto. econstructor; eauto.
  apply regs_inject_regs; auto.
  (* simpl.  *)
  (* eapply compat_frameinj_pop_right; eauto. *)
  (* eapply Mem.inject_push_new_stage_left; eauto. *)
  (* rewrite_stack_blocks. rewrite EQstk'. congruence. *)
  (* { *)
  (*   revert CFG. unfold upstar. *)
  (*   eapply compat_frameinj_pop_right; eauto. *)
  (* } *)
  (* eauto. *)

+ (* call that remains a call *)
  left. exists (Callstate (Stackframe res (transf_function f) tc0 (Vptr sp' Ptrofs.zero) pc' rs' :: s')
                          (transf_fundef fd) (rs'##args) m' (fn_stack_requirements id) false); split.
  eapply exec_Icall; eauto.
  eapply ros_is_function_transf; eauto.
  apply sig_preserved.
  econstructor; eauto. constructor; eauto.
  apply regs_inject_regs; auto. 

- (* tailcall *)
  exploit find_function_translated; eauto. intro FIND'.
  exploit Mem.free_parallel_inject; eauto. constructor.
  intros [m'1 [FREE EXT]].
  (* exploit Mem.unrecord_stack_block_inject_parallel. apply EXT. eauto. *)
  (* { *)
  (*   red in CFG. simpl in CFG. *)
  (*   intros i1 i2 Gi LT. *)
  (*   eapply compat_frameinj_rec_above in Gi. 2: apply CFG. omega. omega. *)
  (* } *)
  (* { *)
  (*   apply CFG. *)
  (* } *)
  (* intros (m2' & USB' & UINJ). *)
  TransfInstr.
  left. exists (Callstate (StackframeTailcalled tc0 :: s') (transf_fundef fd) (rs'##args) m'1 (fn_stack_requirements id) true); split.
  eapply exec_Itailcall; eauto.
  eapply ros_is_function_transf; eauto.
  apply sig_preserved.
  rewrite stacksize_preserved; auto. rewrite ! Z.add_0_r in FREE. eauto.
  econstructor; eauto.
  admit.                        (* we could/should rule out this case since there's no tailcall in the source. *)
  apply regs_inject_regs; auto.

- (* builtin *)
  TransfInstr.
  exploit (@eval_builtin_args_inject _ _ _ _ ge tge (fun r => rs#r) (fun r => rs'#r) (Vptr sp0 Ptrofs.zero)); eauto.
  {
    simpl. intros; rewrite symbols_preserved; auto.
  }
  {
    simpl; intros.
    eapply IG; eauto. eapply Genv.genv_symb_range; eauto.
  }
  intros (vargs' & P & Q).
  exploit external_call_mem_inject; eauto.
  eapply inject_globals_meminj_preserves_globals; eauto.
  intros [f' [v' [m'1 [A [B [C [D [E [F G]]]]]]]]].
  left. exists (State s' (transf_function f) tc0 (Vptr sp' Ptrofs.zero) pc' (regmap_setres res v' rs') m'1); split.
  eapply exec_Ibuiltin; eauto.
  eapply external_call_symbols_preserved; eauto. apply senv_preserved.
  econstructor. 3: eauto.
  all: eauto.
  eapply match_stackframes_incr; eauto.
  apply set_res_inject; auto.
  red; intros; eauto.
  eapply inject_globals_incr; eauto.
  intros.
  specialize (G _ _ _ H2 H3). unfold Mem.valid_block in G.
  red in MSG. simpl in MSG.
  red in MSG'. simpl in MSG'.
  rewrite genv_next_preserved in MSG'. xomega.

- (* cond *)
  TransfInstr.
  left. exists (State s' (transf_function f) tc0 (Vptr sp' Ptrofs.zero) (if b then ifso else ifnot) rs' m'); split.
  eapply exec_Icond; eauto.
  eapply eval_condition_inject. apply regs_inject_regs; auto.
  eauto. eauto. auto.
  econstructor; eauto.

- (* jumptable *)
  TransfInstr.
  left. exists (State s' (transf_function f) tc0 (Vptr sp' Ptrofs.zero) pc' rs' m'); split.
  eapply exec_Ijumptable; eauto.
  generalize (RLD arg). rewrite H0. intro. inv H2. auto.
  econstructor; eauto.

- (* return *)
  exploit Mem.free_parallel_inject; eauto. constructor. intros [m'1 [FREE EXT]].
  exploit Mem.unrecord_stack_block_inject_parallel. apply EXT. eauto.
  {
    red in CFG. simpl in CFG.
    intros i1 i2 Gi LT.
    eapply compat_frameinj_rec_above in Gi. 2: apply CFG. admit. omega.
  }
  {
    apply CFG.
  }
  repeat rewrite_stack_blocks.
  inv MSA'. simpl in H2. destruct H2 as (sinit & EQ & LF). rewrite EQ.
  inv MSA. simpl in H2. destruct H2 as (sinit1 & EQ1 & LF1). rewrite EQ1.
  unfold stack_blocks_of_state in LF, LF1. simpl in LF, LF1. inv LF; inv LF1. simpl.
  intros (m2' & USB' & UINJ).
  TransfInstr.
  left. exists (Returnstate s' (regmap_optget or Vundef rs') m2'); split.
  eapply exec_Ireturn; eauto.
  rewrite stacksize_preserved; auto. rewrite ! Z.add_0_r in FREE. eauto.
  econstructor; eauto.
  destruct or; simpl. apply RLD. constructor.
  auto.
  destruct CFG as (G0 & CFG).
  eapply compat_frameinj_rec_pop_parallel; eauto.

- (* eliminated return None *)
  assert (or = None) by congruence. subst or.
  right. split. simpl. omega. split. auto.
  econstructor. eauto. simpl. constructor.
  eapply Mem.unrecord_stack_block_inject_left'.
  eapply Mem.free_left_inject; eauto. eauto.
  apply CFG.
  erewrite Mem.free_stack_blocks; eauto.
  destruct MSA as (sprog & sinit & EQstk & LF2).
  inv LF2. simpl in EQstk.
  rewrite EQstk. unfold is_stack_top. simpl.
  destruct H6 as (frameblocks & PERM).
  rewrite frameblocks. intros b [|[]]; subst.
  intros o k p P.
  rewrite Mem.perm_free in P; eauto.
  destruct P as (P & Q).
  intuition. apply PERM in Q. intuition.
  red; red in CFG.
  simpl in CFG.
  destruct CFG as (G0 & CFG).
  eapply compat_frameinj_rec_pop_left; eauto.
  auto.

- (* eliminated return Some *)
  assert (or = Some r) by congruence. subst or.
  right. split. simpl. omega. split. auto.
  econstructor. eauto.
  simpl. auto.
  eapply Mem.unrecord_stack_block_inject_left'.
  eapply Mem.free_left_inject; eauto. eauto.
  apply CFG.
  erewrite Mem.free_stack_blocks; eauto.
  destruct MSA as (sprog & sinit & EQstk & LF2).
  inv LF2. simpl in EQstk.
  rewrite EQstk. unfold is_stack_top. simpl.
  destruct H6 as (frameblocks & PERM).
  rewrite frameblocks. intros b [|[]]; subst.
  intros o k p P.
  rewrite Mem.perm_free in P; eauto.
  destruct P as (P & Q).
  intuition. apply PERM in Q. intuition.
  red; red in CFG.
  simpl in CFG.
  destruct CFG as (G0 & CFG).
  eapply compat_frameinj_rec_pop_left; eauto.
  auto.

- (* internal call *)
  exploit Mem.alloc_parallel_inject; eauto.
  + instantiate (1 := 0). omega.
  + instantiate (1 := fn_stacksize f). omega.
  + intros [f' [m'1 [b2 [ALLOC [INJ [INCR [FEQ FOLD]]]]]]].
    assert (EQ: fn_stacksize (transf_function f) = fn_stacksize f /\
                fn_entrypoint (transf_function f) = fn_entrypoint f /\
                fn_params (transf_function f) = fn_params f).
    {
      unfold transf_function. destruct (zeq (fn_stacksize f) 0); auto.
    }
    destruct EQ as [EQ1 [EQ2 EQ3]].
    exploit Mem.record_stack_blocks_inject_parallel. apply INJ. 7: eauto.
    instantiate (1 := make_singleton_frame_adt b2 (fn_stacksize f) sz).
    * red. red. simpl. constructor; auto. simpl. rewrite FEQ.
      intros b0 delta A. inv A. rewrite pred_dec_true; auto.
      eexists; split; eauto.
      split; simpl; auto. intros; omega.
    * unfold in_frame; simpl.
      erewrite Mem.alloc_stack_blocks; eauto.
      intros b IFR [|[]]; subst.
      eapply Mem.in_frames_valid in IFR. eapply Mem.fresh_block_alloc in IFR; eauto.
    * red.
      intros b [|[]]; subst. simpl.
      eapply Mem.valid_new_block; eauto.
    * intros b fi [A|[]]; inv A. simpl.
      intros; eapply Mem.perm_alloc_3; eauto.
    * intros b1 b0 delta FB.
      unfold in_frame; simpl.
      split; intros [|[]]; subst; left. congruence.
      destruct (peq stk b1); auto. rewrite FOLD in FB; auto.
      eapply Mem.valid_block_inject_2 in FB; eauto.
      eapply Mem.fresh_block_alloc in FB; eauto. easy.
    * reflexivity.
    * intros (m2' & RSB & UINJ).
      left. econstructor; split.
      -- simpl. eapply exec_function_internal; eauto. rewrite EQ1; eauto.
         rewrite EQ1; eauto.
      -- rewrite EQ2. rewrite EQ3. econstructor. 3: eauto.
         all: eauto.
         eapply match_stackframes_incr; eauto.
         apply regs_inject_init_regs. auto.
         eapply val_inject_list_incr; eauto.
         red in CFG; red. simpl. split; auto.
         eapply compat_frameinj_rec_push_parallel; eauto.
         intros; destr. omega.
         eapply inject_globals_incr; eauto.
         intros.
         destruct (peq b1 stk). subst. rewrite FEQ in H2; inv H2.
         red in MSG. simpl in MSG.
         red in MSG'. simpl in MSG'.
         rewrite genv_next_preserved in MSG'.
         apply Mem.alloc_result in H. apply Mem.alloc_result in ALLOC. subst. xomega.
         rewrite FOLD in H2. congruence. auto.
         
- (* external call *)
  exploit external_call_mem_inject; eauto.
  eapply inject_globals_meminj_preserves_globals; eauto.
  intros [f' [res' [m2' [A [B [C [D [E [F G]]]]]]]]].
  left. exists (Returnstate s' res' m2'); split.
  econstructor; eauto.
  eapply external_call_symbols_preserved; eauto. apply senv_preserved.
  econstructor. 3: eauto.
  all: eauto.
  eapply match_stackframes_incr; eauto.
  eapply inject_globals_incr; eauto.
  intros.
  specialize (G _ _ _ H0 H1). unfold Mem.valid_block in G.
  red in MSG. simpl in MSG.
  red in MSG'. simpl in MSG'.
  rewrite genv_next_preserved in MSG'. xomega.

- (* returnstate *)
  inv MS0.
+ (* synchronous return in both programs *)
  left. econstructor; split.
  apply exec_return.
  econstructor; eauto. apply set_reg_inject; auto.
+ (* return instr in source program, eliminated because of tailcall *)
  right. split. unfold measure. simpl length.
  change (S (length s) * (niter + 2))%nat
   with ((niter + 2) + (length s) * (niter + 2))%nat.
  generalize (return_measure_bounds (fn_code f) pc). omega.
  split. auto.
  econstructor; eauto.
  rewrite Regmap.gss. auto.
Qed.



Lemma match_state_ge_step:
  forall ge s1 t s1'
    (MSG: match_state_ge ge s1)
    (STEP: step fn_stack_requirements ge s1 t s1'),
    match_state_ge ge s1'.
Proof.
  intros ge0 s1 t s1' MSG STEP.
  inv STEP; red in MSG; red; simpl in *; auto.
  - erewrite Mem.storev_nextblock; eauto.
  - erewrite Mem.unrecord_stack_block_nextblock by eauto.
    erewrite Mem.nextblock_free; eauto.
  - apply external_call_nextblock in H1. xomega.
  - erewrite Mem.unrecord_stack_block_nextblock by eauto.
    erewrite Mem.nextblock_free; eauto.
  - erewrite Mem.record_stack_block_nextblock by eauto.
    erewrite Mem.nextblock_alloc; eauto.
    xomega.
  - apply external_call_nextblock in H. xomega.
Qed.

Lemma match_stack_adt_step:
  forall ge s1 t s1'
    (MSA: match_stack_adt s1)
    (STEP: step fn_stack_requirements ge s1 t s1'),
    match_stack_adt s1'.
Proof.
  intros ge0 s1 t s1' MSA STEP.
  destruct MSA as (sprog & sinit & EQstk & LF2).
  red.
  inv STEP; simpl in *; eauto.
  - erewrite Mem.storev_stack_adt; eauto.
    exists sprog, sinit; split; eauto.
    eapply list_forall2_imply. eauto. simpl.
    intros v1 v2 IN SP V2.
    destr_in V2. destr.
    destruct V2 as (V1 & V2); split; auto.
    intros; eapply V2; eauto.
    eapply Mem.storev_perm_inv; eauto.
  - exists sprog, sinit; split; eauto. simpl.
    unfold stack_blocks_of_state in *. simpl in *.
    destr_in LF2.
    + repeat destr_in Heqo.
      eapply list_forall2_imply. eauto. simpl.
      intros v1 v2 IN SP V2.
      destr_in V2.
    + inv LF2. easy.
  - edestruct Mem.unrecord_stack_adt. eauto.
    erewrite Mem.free_stack_blocks in H1 by eauto.
    rewrite H1 in *.
    unfold stack_blocks_of_state in *; simpl in *.
    inv LF2.
    exists al, sinit; split; eauto.
    inv EQstk. auto.
    eapply list_forall2_imply. eauto. simpl.
    intros v1 v2 IN SP V2.
    destr_in V2.
    destr. destruct V2; split; auto.
    intros; eapply H5.
    eapply Mem.unrecord_stack_block_perm in H6. 2: eauto.
    eapply Mem.perm_free in H6. 2: eauto.
    apply H6.
  - erewrite <- external_call_stack_blocks; eauto.
    exists sprog, sinit; split; auto.
    eapply list_forall2_imply. eauto. simpl.
    intros v1 v2 IN SP V2.
    destr_in V2.
    destr. destruct V2; split; auto.
    intros o k p0 P. erewrite ec_perm_frames in P. eauto.
    eapply external_call_spec. eauto.
    unfold stack_blocks_of_state in SP.
    simpl in SP.
    exploit list_forall2_in_right. apply LF2.
    unfold stack_blocks_of_state. simpl. eauto.
    intros (x1 & INPROG & O & Q).
    rewrite EQstk. apply in_frames_app. left.
    eapply in_frames_in_frame. eauto. red. rewrite O. left; auto.
  - edestruct Mem.unrecord_stack_adt. eauto.
    erewrite Mem.free_stack_blocks in H2 by eauto.
    rewrite H2 in *.
    unfold stack_blocks_of_state in *; simpl in *.
    inv LF2.
    exists al, sinit; split; eauto.
    inv EQstk. auto.
    eapply list_forall2_imply. eauto. simpl.
    intros v1 v2 IN SP V2.
    destr_in V2.
    destr. destruct V2; split; auto.
    intros; eapply H4.
    eapply Mem.unrecord_stack_block_perm in H5. 2: eauto.
    eapply Mem.perm_free in H5. 2: eauto.
    apply H5.
  - erewrite Mem.record_stack_blocks_stack_adt. 2: eauto.
    erewrite Mem.alloc_stack_blocks by eauto.
    unfold stack_blocks_of_state in *; simpl in *.
    exists (make_singleton_frame_adt stk (fn_stacksize f) sz :: sprog), sinit; split; eauto.
    simpl. rewrite EQstk. auto. 
    constructor; auto.
    + split. reflexivity.
      intros.
      eapply Mem.record_stack_block_perm in H1. 2: eauto.
      eapply Mem.perm_alloc_inv in H1. 2: eauto.
      rewrite pred_dec_true in H1; auto.
    + eapply list_forall2_imply. eauto. simpl.
      intros v1 v2 IN SP V2.
      destr_in V2.
      destr. destruct V2; split; auto.
      intros; eapply H2.
      eapply Mem.record_stack_block_perm in H3. 2: eauto.
      eapply Mem.perm_alloc_inv in H3. 2: eauto.
      destr_in H3; eauto.
      contradict e. intro; subst.
      eapply Mem.fresh_block_alloc; eauto.
      eapply Mem.in_frames_valid.
      exploit list_forall2_in_right. apply LF2.
      unfold stack_blocks_of_state. simpl. eauto.
      intros (x1 & INPROG & O & Q).
      rewrite EQstk. apply in_frames_app. left.
      eapply in_frames_in_frame. eauto. red. rewrite O. left; auto.
  - erewrite <- external_call_stack_blocks; eauto.
    exists sprog, sinit; split; auto.
    eapply list_forall2_imply. eauto. simpl.
    intros v1 v2 IN SP V2.
    destr_in V2.
    destr. destruct V2; split; auto.
    intros o k p0 P. erewrite ec_perm_frames in P. eauto.
    eapply external_call_spec. eauto.
    unfold stack_blocks_of_state in SP.
    simpl in SP.
    exploit list_forall2_in_right. apply LF2.
    unfold stack_blocks_of_state. simpl. eauto.
    intros (x1 & INPROG & O & Q).
    rewrite EQstk. apply in_frames_app. left.
    eapply in_frames_in_frame. eauto. red. rewrite O. left; auto.
  - unfold stack_blocks_of_state in *; simpl in *.
    exists sprog, sinit; split; eauto.
    replace (match
      match sp with
      | Vundef => None
      | Vint _ => None
      | Vlong _ => None
      | Vfloat _ => None
      | Vsingle _ => None
      | Vptr sp0 _ => Some (Some (sp0, fn_stacksize f))
      end
    with
    | Some (Some x) => Some x :: map stackblocks_of_stackframe s
    | Some None => map stackblocks_of_stackframe s
    | None => None :: map stackblocks_of_stackframe s
    end) with (match sp with
           | Vundef => None
           | Vint _ => None
           | Vlong _ => None
           | Vfloat _ => None
           | Vsingle _ => None
           | Vptr sp _ => Some (sp, fn_stacksize f)
               end :: map stackblocks_of_stackframe s) by destr.
    auto.
Qed.


Lemma sp_valid_step:
  forall s1 t s1',
    sp_valid s1 ->
    step fn_stack_requirements ge s1 t s1' ->
    sp_valid s1'.
Proof.
  intros s1 t s1' SPV STEP.
  red in SPV; red.
  unfold stack_blocks_of_state in *.
  assert (valid_impl: forall b, Mem.valid_block (mem_state s1) b -> Mem.valid_block (mem_state s1') b).
  {
    inv STEP; simpl in *; intros; red; auto.
    - red; erewrite Mem.storev_nextblock; eauto.
    - erewrite Mem.unrecord_stack_block_nextblock by eauto.
      erewrite Mem.nextblock_free; eauto.
    - apply external_call_nextblock in H1. red in H2. xomega.
    - erewrite Mem.unrecord_stack_block_nextblock by eauto.
      erewrite Mem.nextblock_free; eauto.
    - erewrite Mem.record_stack_block_nextblock by eauto.
      erewrite Mem.nextblock_alloc; eauto.
      red in H1. xomega.
    - apply external_call_nextblock in H. red in H0; xomega.
  }

  assert (SPV': Forall
          (fun bz : option (block * Z) =>
           match bz with
           | Some (b, _) => Mem.valid_block (mem_state s1') b
           | None => True
           end) match current_sp_state s1 with
          | Some (Some x) => Some x :: map stackblocks_of_stackframe (stackframes_state s1)
          | Some None => map stackblocks_of_stackframe (stackframes_state s1)
          | None => None :: map stackblocks_of_stackframe (stackframes_state s1)
          end).
  {
    eapply Forall_impl. 2: eauto. simpl; intros.
    destr_in H0. destr. eauto.
  }
  inv STEP; simpl in *; intros; eauto.
  - constructor; auto. destr. destr. destr_in Heqo. inv Heqo. inv SPV'; auto.
    repeat destr_in SPV; inv SPV'; auto.
  - inv SPV'; auto.
  - inv SPV'; auto.
  - constructor; auto. red; erewrite Mem.record_stack_block_nextblock by eauto.
    eapply Mem.valid_new_block; eauto.
  - inv SPV'; auto.
    repeat destr; constructor; auto.
    destr. destr_in Heqo.
Qed.

Definition match_states' s1 s2 :=
  match_states s1 s2 /\ match_stack_adt s1 /\ match_stack_adt s2 /\
  sp_valid s1 /\ match_state_ge ge s1 /\ match_state_ge tge s2.

Hint Resolve match_stack_adt_step match_state_ge_step sp_valid_step.

Lemma transf_step_correct':
  forall s1 t s2,
    step fn_stack_requirements ge s1 t s2 ->
    forall s1',
      match_states' s1 s1' ->
      (exists s2', step fn_stack_requirements tge s1' t s2' /\ match_states' s2 s2') \/
      (measure s2 < measure s1)%nat /\ t = E0 /\ match_states' s2 s1'.
Proof.
  intros s1 t s2 STEP s1' MS.
  destruct MS as (MS & MSA & MSA' & SPV & MSG & MSG').
  edestruct (transf_step_correct _ _ _ STEP _ MS) as
      [(s2' & STEP' & MS')|(MLT & TE0 & MS')]; eauto.
  - left. eexists; split; eauto.
    repeat split; eauto.
  - right; repeat split; eauto.
Qed.

Lemma transf_initial_states:
  forall st1, initial_state fn_stack_requirements prog st1 ->
  exists st2, initial_state fn_stack_requirements tprog st2 /\ match_states' st1 st2.
Proof.
  intros. inv H.
  exploit funct_ptr_translated; eauto. intro FIND.
  exists (Callstate nil (transf_fundef f) nil m2 (fn_stack_requirements (prog_main tprog))); split.
  econstructor; eauto. apply (Genv.init_mem_transf TRANSL). auto.
  replace (prog_main tprog) with (prog_main prog).
  rewrite symbols_preserved. eauto.
  symmetry; eapply match_program_main; eauto. 
  rewrite <- H3. apply sig_preserved.
  erewrite <- match_program_main; eauto.
  
  edestruct Mem.alloc_parallel_inject as (f' & m2' & b2 & ALLOC & INJ & INCR & JNEW & JOLD).
  eapply Genv.initmem_inject; eauto. eauto. apply Zle_refl. apply Zle_refl.
  rewrite ALLOC in H4 ; inv H4.
  assert (forall b, f' b = Mem.flat_inj (Mem.nextblock m2) b).
  {
    unfold Mem.flat_inj.
    intros.
    erewrite Mem.record_stack_block_nextblock. 2: eauto.
    erewrite Mem.nextblock_alloc. 2: eauto.
    apply Mem.alloc_result in ALLOC. subst. 
    destr.
    - apply Plt_succ_inv in p.
      destruct p; subst; auto.
      rewrite JOLD. unfold Mem.flat_inj; destr.
      apply Plt_ne; auto.
    - rewrite JOLD.
      unfold Mem.flat_inj; destr. xomega.
      intro; subst. xomega.
  }
  edestruct Mem.record_stack_blocks_inject_parallel as (m2'' & RSB & INJ'); eauto.
  + eapply frame_inject_ext.         
    apply Mem.frame_inject_flat. simpl. constructor; simpl; auto.
    eapply Mem.valid_new_block. eauto.
    intros; rewrite H.
    erewrite <- Mem.record_stack_block_nextblock. 2: eauto.
    reflexivity.
  + erewrite Mem.alloc_stack_blocks. 2: eauto.
    intros b0 INS [|[]]. subst. simpl in INS.
    apply Mem.in_frames_valid in INS.
    eapply Mem.fresh_block_alloc; eauto.
  + red; simpl. intros b0 [|[]]. simpl in *; subst.
    eapply Mem.valid_new_block; eauto.
  + intros b0 fi [AA|[]]. inv AA.
    intros.
    eapply Mem.perm_alloc_inv in ALLOC; eauto. destr_in ALLOC.
  + unfold in_frame; simpl.
    intros b0 b2 delta. rewrite H. unfold Mem.flat_inj.
    intro FI; repeat destr_in FI.
  + exploit Mem.record_stack_block_det. apply H5. apply RSB. intro; subst m2''.
    split.
    econstructor. constructor. constructor.
    eauto.
    red; simpl.
    intros; omega.
    exploit Genv.init_mem_genv_next. eauto. intro EQ. fold ge in EQ.
    erewrite Mem.record_stack_block_nextblock in H; eauto.
    erewrite Mem.nextblock_alloc in H; eauto.
    split.
    * intros b0 PLT. rewrite H. unfold Mem.flat_inj. rewrite pred_dec_true; auto. rewrite <- EQ; xomega.
    * intros b0 b2 delta FB PLT. rewrite H in FB.
      unfold Mem.flat_inj in FB. destr_in FB.
    * repeat split.
      -- red; simpl.
         unfold stack_blocks_of_state. simpl.
         exists nil, (Mem.stack_adt m2); split; eauto. constructor.
      -- red; simpl.
         unfold stack_blocks_of_state. simpl.
         exists nil, (Mem.stack_adt m2); split; eauto. constructor.
      -- red; simpl. constructor.
      -- red. simpl.
         erewrite Mem.record_stack_block_nextblock; eauto.
         erewrite Mem.nextblock_alloc; eauto.
         unfold ge; erewrite Genv.init_mem_genv_next; eauto. xomega.
      -- red. simpl.
         erewrite Mem.record_stack_block_nextblock; eauto.
         erewrite Mem.nextblock_alloc; eauto.
         erewrite genv_next_preserved.
         unfold ge; erewrite Genv.init_mem_genv_next; eauto. xomega.
Qed.

Lemma transf_final_states:
  forall st1 st2 r,
  match_states' st1 st2 -> final_state st1 r -> final_state st2 r.
Proof.
  intros. inv H0. inv H. inv H0. inv LDret. inv MS. constructor.
Qed.



(** The preservation of the observable behavior of the program then
  follows. *)

Theorem transf_program_correct:
  forward_simulation (RTL.semantics fn_stack_requirements prog) (RTL.semantics fn_stack_requirements tprog).
Proof.
  eapply forward_simulation_opt with (measure := measure); eauto.
  apply senv_preserved. 
  eexact transf_initial_states.
  eexact transf_final_states.
  simpl; intros; eapply transf_step_correct'; eauto.
Qed.

End PRESERVATION.

