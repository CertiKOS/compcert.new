Require compcert.backend.CSEproof.
Require CSEX.
Require ValueAnalysisX.
Require SmallstepX.

Import Coqlib.
Import Errors.
Import AST.
Import Values.
Import Memory.
Import Events.
Import SmallstepX.
Import Globalenvs.
Import CSEX.
Import ValueDomainX.
Import ValueAnalysisX.
Export CSEproof.

Section WITHCONFIG.
Context `{external_calls_prf: ExternalCalls}.
Local Existing Instance romem_for_empty_instance.

Variable prog: RTL.program.
Variable tprog: RTL.program.
Variable fn_stack_requirements: ident -> Z.

Hypothesis TRANSF: transf_program prog = OK tprog.

Let MATCH_PROG: match_prog prog tprog.
Proof. apply transf_program_match; auto. Qed.

Let ge : RTL.genv := Genv.globalenv prog.
Let tge: RTL.genv := Genv.globalenv tprog.

Lemma genv_next_preserved:
  Genv.genv_next tge = Genv.genv_next ge.
Proof.
  unfold transf_program, transf_fundef in TRANSF.
  eapply CSEproof.genv_next_preserved; eauto.
Qed.

Lemma transf_initial_states:
  forall i init_m sg args,
  forall S, RTLX.initial_state fn_stack_requirements prog i init_m sg args S ->
  exists R, RTLX.initial_state fn_stack_requirements tprog i init_m sg args R /\ match_states prog S R.
Proof.
  unfold transf_program, transf_fundef in TRANSF.
  intros. inv H.
  exploit funct_ptr_translated; eauto. intros (? & f' & ? & ? & ?).
  exists (RTL.Callstate nil f' args (Mem.push_new_stage init_m) (fn_stack_requirements i)); split.
  econstructor; eauto.
  erewrite symbols_preserved; eauto.
  symmetry. eapply sig_preserved; eauto.
  econstructor; eauto.
  econstructor.
  exact (val_lessdef_refl _).
  apply Mem.extends_refl.
Qed.

Lemma transf_final_states:
  forall sg,
  forall st1 st2 r, 
  match_states prog st1 st2 -> RTLX.final_state sg st1 r ->
  final_state_with_extends (RTLX.final_state sg) st2 r.
Proof.
  intros. inv H0. inv H.
  inv STACK.
  edestruct Mem.unrecord_stack_block_extends as (m2' & USB' & EXT'); eauto.
  econstructor; eauto.
  constructor; auto.
Qed.

(** To prove that the initial per-function state is sound with respect
    to value analysis, we need the following hypotheses, which
    actually hold thanks to the properties on the caller in assembly
    code (see [AsmX.asm_invariant] for the invariant on the assembly
    state, and [Asm.exec_step_external] for the conditions local to
    the function call site.)
*)

Variable init_m: mem.
Variable args: list val.

Hypotheses
  (INJECT_NEUTRAL: Mem.inject_neutral (Mem.nextblock init_m) init_m)
  (GENV_NEXT: Ple (Genv.genv_next ge) (Mem.nextblock init_m))
  (ARGS_INJECT_NEUTRAL: Val.inject_list (Mem.flat_inj (Mem.nextblock init_m)) args args).

Theorem transf_program_correct:
  forall i sg,
  forward_simulation 
    (RTLX.semantics fn_stack_requirements prog i init_m sg args)
    (semantics_with_extends (RTLX.semantics fn_stack_requirements tprog i init_m sg args)).
Proof.
  unfold transf_program, transf_fundef in TRANSF.
  intros.
  eapply forward_simulation_step with
    (match_states := fun s1 s2 => sound_state prog s1 /\ match_states prog s1 s2 /\ RTL.stack_equiv_inv s1 s2 /\ RTL.stack_inv s2);
    simpl.
  - eapply senv_preserved; eauto.
  - intros. exploit transf_initial_states; eauto. intros [s2 [A B]]. 
    exists s2. split. auto. split. eapply sound_initial; eauto. split; auto.
    split. inv H; inv A. red. simpl.
    apply stack_equiv_refl; auto.
    eapply RTLX.initial_stack_inv; eauto.
  - intros s1 s2 r (SOUND & MS & SEI & SI) FS. eapply transf_final_states; eauto.
  - intros s1 t s1' STEP s2 (SOUND & MS & SEI & SI).
    edestruct transf_step_correct as (s2' & STEP' & MS'); eauto.
    eexists; split; eauto. split.
    eapply sound_step; eauto.
    split. auto.
    split.
    eapply stack_equiv_inv_step; eauto.
    eapply RTL.stack_inv_inv; eauto.
Qed.

End WITHCONFIG.
