Require Import LogicalRelations.
Require Import Axioms.
Require Import Classical.
Require Import Sets.
Require Import KLR.
Require Export Games.


(** * Prerequisites *)

Axiom prop_ext : ClassicalFacts.prop_extensionality.


(** * Receptive transition systems *)

(** We do metatheory in a setting ...
  The whole thing in this file is parametrized by a set of events [E]
  and a set of moves [M]. Events can only ever serve as outputs,
  whereas moves can be used both as outputs and inputs. *)

Module RTS.

  (** ** Definition *)

  (** Continuations *)

  Inductive resumption {A} :=
    | resume (a : A)
    | reject.

  Arguments resumption : clear implicits.

  Inductive resumption_rel {A B} (R : rel A B) : rel _ _ :=
    | resumption_rel_resume a b :
        R a b -> resumption_rel R (resume a) (resume b)
    | resumption_rel_reject :
        resumption_rel R reject reject.

  Global Instance resume_rel :
    Monotonic (@resume) (forallr R, R ++> resumption_rel R).
  Proof.
    constructor; auto.
  Qed.

  Global Instance reject_rel :
    Monotonic (@reject) (forallr R, resumption_rel R).
  Proof.
    constructor; auto.
  Qed.

  Global Instance resumption_subrel {A B} :
    Monotonic (@resumption_rel A B) (subrel ++> subrel).
  Proof.
    intros RA RB HR b1 b2 Hb.
    destruct Hb; constructor; rauto.
  Qed.

  Global Instance resumption_subrel_params :
    Params (@resumption_rel) 3.

  Global Instance resumption_rel_refl `{Reflexive} :
    Reflexive (resumption_rel R).
  Proof.
    intro x. destruct x; constructor; auto.
  Qed.

  Global Instance resumption_rel_compose `{RCompose} :
    RCompose
      (resumption_rel RAB)
      (resumption_rel RBC)
      (resumption_rel RAC).
  Proof.
    destruct 1; inversion 1; subst; constructor.
    ercompose; eauto.
  Qed.

  Definition resumption_map {A B} (f : A -> B) (r : resumption A) :=
    match r with
      | resume s => resume (f s)
      | reject => reject
    end.

  Global Instance resumption_map_rel :
    Monotonic
      (@resumption_map)
      (forallr RA, forallr RB, (RA ++> RB) ++>
       resumption_rel RA ++> resumption_rel RB).
  Proof.
    unfold resumption_map. rauto.
  Qed.

  Definition cont G A :=
    move G -> set (resumption A).

  Definition cont_le {GA GB A B} GR R: klr (gworld GR) (cont GA A) (cont GB B) :=
    [] move_rel GR ++> k1 set_le (k1 resumption_rel R).

  Hint Unfold cont_le : typeclass_instances.

  Global Instance cont_le_refl {G A} R `{!forall w, @Reflexive A (R w)} w :
    Reflexive (cont_le (@grel_id G) R w).
  Proof.
    intros x w' Hw' q _ [ ]. unfold k1. reflexivity.
  Qed.

  Global Instance cont_le_compose {GA GB GC A B C} GRAB GRBC RAB RBC RAC wab wbc :
    (forall wab' wbc', @RCompose A B C (RAB wab') (RBC wbc') (RAC (wab', wbc'))) ->
    RCompose
      (cont_le GRAB RAB wab)
      (cont_le GRBC RBC wbc)
      (cont_le (@grel_compose GA GB GC GRAB GRBC) RAC (wab, wbc)).
  Proof.
    intros H k1 k2 k3 H12 H23 [w12' w23'] [Hw12' Hw23'] q1 q3 (q2 & Hq12 & Hq23).
    specialize (H12 w12' Hw12' q1 q2 Hq12).
    specialize (H23 w23' Hw23' q2 q3 Hq23).
    rcompose (k2 q2); eauto.
  Qed.

  Definition cont_map {G A B} (f : A -> B) (k : cont G A) : cont G B :=
    fun q => set_map (resumption_map f) (k q).

  Global Instance cont_map_le :
    Monotonic
      (@cont_map)
      (forallr GR, forallr R : klr _, forallr S : klr _,
        (rforall w, R w ++> S w) ++>
        (rforall w, cont_le GR R w ++> cont_le GR S w)).
  Proof.
    unfold cont_map. rauto.
  Qed.

  (** The possible behaviors of each state in a RTS are as follows. *)

  Inductive behavior {G A} :=
    | internal (a' : A)
    | interacts (m : move G) (k : cont G A)
    | diverges
    | goes_wrong.

  Arguments behavior : clear implicits.

  Inductive behavior_le {GA GB} GR {A B} R : klr _ (behavior GA A) (behavior GB B) :=
    | internal_le :
        Monotonic internal ([] R ++> behavior_le GR R)
    | interacts_le_def w w' p1 p2 k1 k2 :
        w ~> w' ->
        move_rel GR w' p1 p2 ->
        cont_le GR R w' k1 k2 ->
        behavior_le GR R w (interacts p1 k1) (interacts p2 k2)
    | diverges_le :
        Monotonic diverges ([] behavior_le GR R)
    | goes_wrong_le ra :
        Related ra goes_wrong ([] behavior_le GR R).

  Global Existing Instance internal_le.
  Global Existing Instance diverges_le.
  Global Existing Instance goes_wrong_le.
  Global Instance internal_le_params : Params (@internal) 1.

  Global Instance interacts_le :
    Monotonic (@interacts)
      (forallr GR, forallr R,
         [] % (<> move_rel GR * cont_le GR R) ++> behavior_le GR R).
  Proof.
    repeat rstep.
    destruct x as [p1 k1], y as [p2 k2], H as (w' & Hw' & Hp & Hk). cbn in *.
    econstructor; eauto.
  Qed.

  Global Instance behavior_le_refl {G A} R w :
    (forall w, @Reflexive A (R w)) ->
    Reflexive (behavior_le (@grel_id G) R w).
  Proof.
    intros H [a' | m k | | ]; try constructor; eauto.
    - reflexivity.
    - rstep. exists tt; simpl; intuition repeat rstep.
      destruct H0. reflexivity.
  Qed.

  Global Instance behavior_le_compose {GA GB GC GRAB GRBC A B C RAB RBC RAC} wab wbc :
    (forall wab wac, @RCompose A B C (RAB wab) (RBC wac) (RAC (wab, wac))) ->
    RCompose
      (behavior_le GRAB RAB wab)
      (behavior_le GRBC RBC wbc)
      (behavior_le (@grel_compose GA GB GC GRAB GRBC) RAC (wab, wbc)).
  Proof.
    intros H.
    destruct 1; inversion 1; subst; try constructor; eauto.
    - ercompose; eauto.
    - econstructor.
      + rauto.
      + ercompose; eauto.
      + ercompose; eauto.
  Qed.

  Definition behavior_map {G A B} (f : A -> B) (r : behavior G A) :=
    match r with
      | internal a' => internal (f a')
      | interacts m k => interacts m (cont_map f k)
      | diverges => diverges
      | goes_wrong => goes_wrong
    end.

  Global Instance behavior_map_le :
    Monotonic
      (@behavior_map)
      (forallr GR, forallr RA : klr _, forallr RB : klr _,
       ([] RA ++> RB) ++> [] behavior_le GR RA ++> behavior_le GR RB).
  Proof.
    unfold behavior_map. rauto.
  Qed.

  (** A receptive transition system simply assigns a set of possible
    behaviors to each state. *)

  Definition rts G A :=
    rel A (behavior G A).

  Bind Scope rts_scope with rts.
  Delimit Scope rts_scope with rts.

  (** ** Simulations *)

  (** A simulation between two RTS assets that each possible behavior
    in the first has a correponding behavior in the second. In
    particular, internal transitions must correspond one-to-one. *)

  Definition sim {GA GB} GR {A B} R : rel (rts GA A) (rts GB B) :=
    ([] R ++> k1 set_le (behavior_le GR R)).

  Arguments sim {GA GB} GR%grel {A B} R%rel α%rts β%rts.

  Hint Unfold sim : typeclass_instances.

  Hint Extern 1 (Transport _ _ _ (?α _ _) _) =>
    match type of α with rts _ _ => set_le_transport α end
    : typeclass_instances.

  Lemma sim_id {G A} (α : rts G A) :
    sim grel_id (fun _ => eq) α α.
  Proof.
    intros w a _ [ ] a' Ha'. exists a'. split; eauto. reflexivity.
  Qed.

  Global Instance sim_compose {GA GB GC GRAB GRBC A B C RAB RBC RAC} :
    (forall wab wbc, RDecompose (RAB wab) (RBC wbc) (RAC (wab, wbc))) ->
    (forall wab wbc, RCompose (RAB wab) (RBC wbc) (RAC (wab, wbc))) ->
    @RCompose (rts GA A) (rts GB B) (rts GC C)
      (sim GRAB RAB)
      (sim GRBC RBC)
      (sim (grel_compose GRAB GRBC) RAC).
  Proof.
    intros HRD HRC α β γ Hαβ Hβγ [wab wbc] a c Hac. red in Hαβ, Hβγ.
    rdecompose Hac as (b & Hab & Hac).
    rcompose (β b); rauto.
  Qed.

  (** ** Externally observable behaviors *)

  (** Given a RTS, we can define a reduced version that only contains
    observable behaviors: internal transitions are hidden, except in
    the case of silent divergence. *)

  CoInductive forever_internal {G A} (α : rts G A) (a : A) : Prop :=
    | forever_internal_intro a' :
        α a (internal a') ->
        forever_internal α a' ->
        forever_internal α a.

  Inductive reachable {G A} (α : rts G A) : relation A :=
    | reachable_refl a :
        reachable α a a
    | reachable_step a a' a'' :
        α a (internal a') ->
        reachable α a' a'' ->
        reachable α a a''.

  Inductive behavior_external {G A} : behavior G A -> Prop :=
    | interacts_external m k :
        behavior_external (interacts m k)
    | diverges_external :
        behavior_external diverges
    | goes_wrong_external :
        behavior_external goes_wrong.

  Inductive obs {G A} (α : rts G A) a : behavior G A -> Prop :=
    | obs_diverges :
        forever_internal α a ->
        obs α a diverges
    | obs_external a' r :
        behavior_external r ->
        α a' r ->
        reachable α a a' ->
        obs α a r.

  Hint Resolve reachable_refl.
  Hint Immediate reachable_step.
  Hint Constructors behavior_external.
  Hint Constructors obs.

  Global Instance reachable_trans {G A} (α : rts G A) :
    Transitive (reachable α).
  Proof.
    intros a a' a'' Ha' Ha''.
    induction Ha'; auto.
    econstructor; eauto.
  Qed.

  (** Observations are compatible with simulations. *)

  Lemma forever_internal_sim {GA GB A B} (GR : grel GA GB) (R : klr _ A B) w α β a b :
    sim GR R α β ->
    R w a b ->
    forever_internal α a ->
    forever_internal β b \/ obs β b goes_wrong.
  Proof.
    intros Hαβ Hab Ha.
    destruct (classic (obs β b goes_wrong)); eauto. left.
    revert a b Hab H Ha. cofix IH. intros.
    destruct Ha as [a' Ha' Hda'].
    edestruct Hαβ as (rb & Hb' & Hrab); eauto.
    inversion Hrab; clear Hrab; subst.
    - econstructor; eauto.
      eapply IH; eauto.
      inversion 1; eauto.
    - destruct H.
      econstructor; eauto.
  Qed.

  Lemma reachable_sim {GA GB A B} (GR : grel GA GB) (R : klr _ A B) w α β a b a' :
    sim GR R α β ->
    R w a b ->
    reachable α a a' ->
    exists b',
      reachable β b b' /\
      (R w a' b' \/ β b' goes_wrong).
  Proof.
    intros Hαβ Hab Ha'. revert b Hab.
    induction Ha' as [a | a a' a'' Ha' Ha'' IHa'']; eauto.
    intros b Hab.
    edestruct Hαβ as (rb' & Hb' & Hab'); eauto.
    inversion Hab'; clear Hab'; subst; eauto.
    edestruct IHa'' as (b'' & Hb'' & Hab''); eauto.
  Qed.

  Global Instance behavior_external_sim :
    Monotonic
      (@behavior_external)
      (forallr GR, forallr R, rforall w, behavior_le GR R w ++> impl).
  Proof.
    intros GA GB GR A B R w a b Hab Ha.
    destruct Ha; inversion Hab; eauto.
  Qed.

  Hint Extern 10 (Transport _ _ _ (behavior_external _) _) =>
    eapply impl_transport : typeclass_instances.

  Global Instance obs_sim :
    Monotonic
      (@obs)
      (forallr GR, forallr R : klr _, sim GR R ++> sim GR R).
  Proof.
    intros GA GB GR A B R α β Hαβ w a b Hab ra Hra.
    destruct Hra as [Ha | a' ra Hext Hra Ha' ].
    - edestruct @forever_internal_sim as [Hb | Hb]; eauto.
      + exists diverges. split; eauto. rauto.
      + exists goes_wrong. split; eauto. rauto.
    - edestruct @reachable_sim as (b' & Hb' & [Hab' | Hgw]); eauto.
      + edestruct Hαβ as (rb & Hrb & Hr); eauto.
        transport Hext. eauto.
      + exists goes_wrong. split; eauto. rauto.
  Qed.

  (** Additional properties. *)

  Lemma obs_behavior_external {G A} (α : rts G A) a r :
    obs α a r ->
    behavior_external r.
  Proof.
    destruct 1; eauto.
  Qed.

  Lemma obs_internal_inv {G A} (α : rts G A) a a' :
    ~ obs α a (internal a').
  Proof.
    inversion 1.
    inversion H0.
  Qed.

  Lemma reachable_obs {G A} (α : rts G A) a a' :
    reachable (obs α) a a' ->
    reachable α a a'.
  Proof.
    intros Ha'.
    destruct Ha'; eauto.
    eelim obs_internal_inv; eauto.
  Qed.

  Lemma forever_internal_reachable {G A} (α : rts G A) a a' :
    reachable α a a' ->
    forever_internal α a' ->
    forever_internal α a.
  Proof.
    induction 1; auto.
    econstructor; eauto.
  Qed.

  Lemma obs_internal {G A} (α : rts G A) a a' r :
    RTS.obs α a' r ->
    α a (RTS.internal a') ->
    RTS.obs α a r.
  Proof.
    intros Hr Ha'.
    destruct Hr.
    - constructor. econstructor; eauto.
    - econstructor; eauto.
  Qed.

  Lemma obs_reachable {G A} (α : rts G A) a a' r :
    obs α a' r ->
    reachable α a a' ->
    obs α a r.
  Proof.
    intros Ha' H.
    induction H; eauto using obs_internal.
  Qed.

  (** ** [obs] is idempotent *)

  Lemma obs_idempotent {G A} (α : rts G A) :
    obs (obs α) = obs α.
  Proof.
    apply functional_extensionality; intros a.
    apply functional_extensionality; intros r.
    apply prop_ext.
    split.
    - intros [Ha | a' ra' Hext Hra' Ha' ].
      + destruct Ha. eelim obs_internal_inv; eauto.
      + eapply reachable_obs in Ha'.
        destruct Hra'.
        * eauto using forever_internal_reachable, reachable_obs.
        * econstructor; eauto.
          etransitivity; eauto.
    - intros [Ha | a' ra' Hra' Hext Ha' ]; eauto.
  Qed.

  (** ** Structural properties *)

  Definition nonbranching_cont {G A} (k1 k2 : cont G A) :=
    forall q r1 r2,
      k1 q r1 ->
      k2 q r2 ->
      r1 = r2.

  Definition nonbranching_behaviors {G A} (r1 r2 : behavior G A) :=
    match r1, r2 with
      | internal a1, internal a2 => a1 = a2
      | interacts m1 k1, interacts m2 k2 => m1 = m2 -> nonbranching_cont k1 k2
      | internal _, _ | _, internal _ => False
      | _, _ => True
    end.

  Definition nonbranching {G A} (α : rts G A) :=
    forall a r1 r2, α a r1 -> α a r2 -> nonbranching_behaviors r1 r2.

  Definition deterministic_behavior {G A} (r : behavior G A) :=
    match r with
      | interacts m k => nonbranching_cont k k
      | _ => True
    end.

  Definition deterministic {G A} (α : rts G A) :=
    forall a r1 r2, α a r1 -> α a r2 -> psat deterministic_behavior r1 r2.

  Lemma deterministic_nonbranching {G A} (α : rts G A) :
    deterministic α ->
    nonbranching α.
  Proof.
    intros Hα a r1 r2 Hr1 Hr2.
    pose proof (Hα a r1 r2 Hr1 Hr2) as [Hr]; eauto.
    destruct r1; simpl; auto.
  Qed.

  Hint Resolve deterministic_nonbranching.

  Lemma nonbranching_internal {G A} (α : rts G A) a a1 a2 :
    nonbranching α ->
    α a (internal a1) ->
    α a (internal a2) ->
    a1 = a2.
  Proof.
    firstorder.
  Qed.

  Lemma nonbranching_internal_external {G A} (α : rts G A) a r a' :
    nonbranching α ->
    behavior_external r ->
    α a r ->
    α a (internal a') ->
    False.
  Proof.
    intros Hα Hrext Hr Ha'.
    destruct Hrext; apply (Hα _ _ _ Hr Ha').
  Qed.

  (** A particular property of nonbranching transition systems is
    that any observable behavior remains unchanged after taking any
    number of silent steps. *)

  Lemma fi_inv_internal {G A} (α : rts G A) a a' :
    nonbranching α ->
    forever_internal α a ->
    α a (internal a') ->
    forever_internal α a'.
  Proof.
    intros Hα Ha Ha'.
    destruct Ha as [a1 Ha1 Ha1div].
    assert (H: a1 = a') by eauto using nonbranching_internal; subst.
    eauto.
  Qed.

  Lemma fi_inv_reachable {G A} (α : rts G A) a a' :
    nonbranching α ->
    forever_internal α a ->
    reachable α a a' ->
    forever_internal α a'.
  Proof.
    intros Hα Ha Ha'.
    induction Ha' as [ | a a' a'' Ha' Ha'' IHa''];
      eauto using fi_inv_internal.
  Qed.

  Lemma reachable_inv_reachable {G A} (α : rts G A) a a' a'' r :
    nonbranching α ->
    behavior_external r ->
    α a'' r ->
    reachable α a a'' ->
    reachable α a a' ->
    reachable α a' a''.
  Proof.
    intros Hα Hrext Hr Ha'' Ha'.
    revert a'' Hr Ha''.
    induction Ha' as [ | a1 a2 a3 Ha12 Ha23]; eauto; intros.
    destruct Ha'' as [ | a1 a' a'' Ha' Ha''].
    - eelim nonbranching_internal_external; eauto.
    - assert (a2 = a') by eauto using nonbranching_internal; subst. eauto.
  Qed.

  Lemma obs_deterministic {G A} (α : rts G A) : (* XXX in RTS.v *)
    deterministic α ->
    deterministic (obs α).
  Proof.
    intros Hα a r1 r2 H1 H2.
    destruct H1.
    - destruct H2. { constructor. simpl. auto. }
      induction H2 as [a | a1 a2 a3 Ha12 Ha23].
      + destruct H. revert H0.
        assert (psat deterministic_behavior (internal a') r) as [Hr] by eauto.
        inversion 1.
      + eapply IHHa23; eauto using fi_inv_internal.
    - destruct H2; eauto.
      + eapply fi_inv_reachable in H2; eauto.
        destruct H2. revert H.
        assert (psat deterministic_behavior (internal a'0) r) as [Hr] by eauto.
        inversion 1.
      + induction H1 as [a | a1 a2 a3 Ha12 Ha23].
        * destruct H4; eauto. revert H.
          assert (psat deterministic_behavior (internal a') r) as [Hr] by eauto.
          inversion 1.
        * apply IHHa23; eauto.
          eapply reachable_inv_reachable; eauto.
  Qed.

  (** ** Sum *)

  (** *** Definition *)

  Inductive sum {G A B} (α : rts G A) (β : rts G B) : rts G (A + B) :=
    | sum_inl a ra : α a ra -> sum α β (inl a) (behavior_map inl ra)
    | sum_inr b rb : β b rb -> sum α β (inr b) (behavior_map inr rb).

  Hint Constructors sum.
  Infix "+" := sum : rts_scope.

  (*
  Global Instance sum_sim :
    Monotonic
      (@sum)
      (forallr GR, forallr RA, forallr RB,
         sim GR RA ++> sim GR RB ++> sim GR (RA + RB)%klr).
  Proof.
    intros GA GB GR A1 A2 RA B1 B2 RB α1 α2 Hα β1 β2 Hβ w s1 s2 Hs s1' Hs1'.
    destruct Hs1'; inversion Hs.
    -
    eapply transport in H.
    Focus 2. rstep.

 transport H; (eexists; split; [eauto | try rauto]).
  Qed.
*)

  (** *** Commutation with [obs] *)

  Lemma inl_reachable {G A B} (α : rts G A) (β : rts G B) a a' :
    reachable α a a' ->
    reachable (α + β) (inl a) (inl a').
  Proof.
    induction 1; eauto.
    econstructor; eauto.
    change (internal (?x ?y)) with (behavior_map (G:=G) x (internal y)).
    constructor; auto.
  Qed.

  Lemma inr_reachable {G A B} (α : rts G A) (β : rts G B) b b' :
    reachable β b b' ->
    reachable (α + β) (inr b) (inr b').
  Proof.
    induction 1; eauto.
    econstructor; eauto.
    change (internal (?x ?y)) with (behavior_map (G:=G) x (internal y)).
    constructor; auto.
  Qed.

  Lemma sum_reachable_inv {G A B} (α : rts G A) (β : rts G B) s s' :
    reachable (α + β) s s' ->
    (exists a a', s = inl a /\ s' = inl a' /\ reachable α a a') \/
    (exists b b', s = inr b /\ s' = inr b' /\ reachable β b b').
  Proof.
    induction 1 as [s | s s' s'' Hs' Hs'' IHs''].
    - destruct s; [left | right]; eauto.
    - destruct IHs'' as [(a' & a'' & ? & ? & Ha'') | (b' & b'' & ? & ? & Hb'')].
      + left. subst. inversion Hs'; clear Hs'; subst.
        * destruct ra; inversion H; clear H; subst. eauto.
        * destruct rb; inversion H.
      + right. subst. inversion Hs'; clear Hs'; subst.
        * destruct ra; inversion H.
        * destruct rb; inversion H; clear H; subst. eauto.
  Qed.

  Lemma inl_forever_internal {G A B} (α : rts G A) (β : rts G B) a :
    forever_internal α a ->
    forever_internal (α + β) (inl a).
  Proof.
    revert a; cofix IH; intros.
    destruct H as [a' Ha' H].
    econstructor; eauto.
    change (internal (inl a')) with (@behavior_map G A (A+B) inl (internal a')).
    econstructor; auto.
  Qed.

  Lemma inr_forever_internal {G A B} (α : rts G A) (β : rts G B) b :
    forever_internal β b ->
    forever_internal (α + β) (inr b).
  Proof.
    revert b; cofix IH; intros.
    destruct H as [b' Hb' H].
    econstructor; eauto.
    change (internal (inr b')) with (@behavior_map G B (A+B) inr (internal b')).
    econstructor; auto.
  Qed.

  Lemma sum_forever_internal_inv {G A B} (α : rts G A) (β : rts G B) s :
    forever_internal (α + β) s ->
    (exists a, s = inl a /\ forever_internal α a) \/
    (exists b, s = inr b /\ forever_internal β b).
  Proof.
    destruct s as [a | b].
    - left. exists a; intuition auto.
      revert a H. cofix IH. intros.
      destruct H as [s' Hs' H].
      inversion Hs'; clear Hs'; subst.
      destruct ra; inversion H1; clear H1; subst.
      econstructor; eauto.
    - right. exists b; intuition auto.
      revert b H. cofix IH. intros.
      destruct H as [s' Hs' H].
      inversion Hs'; clear Hs'; subst.
      destruct rb; inversion H1; clear H1; subst.
      econstructor; eauto.
  Qed.

  Lemma behavior_external_map_inv {G A B} (f : A -> B) (r : behavior G A) :
    behavior_external (behavior_map f r) ->
    behavior_external r.
  Proof.
    destruct r; inversion 1; eauto.
  Qed.

  Lemma sum_obs {G A B} (α : rts G A) (β : rts G B) :
    RTS.sim grel_id (fun _ => eq) (obs (α + β)) (obs α + obs β).
  Proof.
    intros w s _ [ ] r Hr.
    exists r; split; [ | rauto].
    destruct Hr as [Hs | s' r Hrext Hr Hs'].
    - apply sum_forever_internal_inv in Hs as [(a & ? & H) | (b & ? & H)]; subst.
      + change diverges with (behavior_map (G:=G) (@inl A B) diverges).
        left. auto.
      + change diverges with (behavior_map (G:=G) (@inr A B) diverges).
        right. auto.
    - apply sum_reachable_inv in Hs' as [(a & a' & ? & ? & Ha') |
                                         (b & b' & ? & ? & Hb')]; subst;
      inversion Hr; clear Hr; subst;
      eauto using behavior_external_map_inv.
  Qed.

  Lemma obs_sum {G A B} (α : rts G A) (β : rts G B) :
    RTS.sim grel_id (fun _ => eq) (obs α + obs β) (obs (α + β)).
  Proof.
    intros w s _ [ ] r Hr.
    exists r; split; [ | rauto].
    destruct Hr as [a ra Hra | b rb Hrb].
    - destruct Hra.
      + constructor; eauto using inl_forever_internal.
      + econstructor; eauto using inl_reachable. destruct H; constructor.
    - destruct Hrb.
      + constructor; eauto using inr_forever_internal.
      + econstructor; eauto using inr_reachable. destruct H; constructor.
  Qed.

  Global Instance obs_params : Params (@obs) 4.
  Global Instance sum_params : Params (@sum) 6.
End RTS.

Notation rts := RTS.rts.

Delimit Scope rts_scope with rts.
Infix "+" := RTS.sum : rts_scope.


(** * Modules *)

(** ** Definition *)

Record modsem {G : game} :=
  {
    modsem_state : Type;
    modsem_lts :> rts G modsem_state;
    modsem_entry : RTS.cont G modsem_state;
  }.

Arguments modsem : clear implicits.

Bind Scope modsem_scope with modsem.
Delimit Scope modsem_scope with modsem.

(** ** Refinement preorder *)

Record modref {GA GB} (GR : grel GA GB) (α β : modsem _) : Prop :=
  {
    modref_state :
      klr (gworld GR) (modsem_state α) (modsem_state β);
    modref_sim :
      RTS.sim GR modref_state (modsem_lts α) (modsem_lts β);
    modref_init :
      RTS.cont_le GR modref_state (ginitw GR) (modsem_entry α) (modsem_entry β);
  }.

(*
Global Instance modref_preo li:
  PreOrder (@modref li).
Proof.
  split.
  - intros [A α a].
    exists eq; simpl.
    + apply RTS.sim_id.
    + intros q. reflexivity.
  - intros [A α a] [B β b] [C γ c] [RAB Hαβ Hab] [RBC Hβγ Hbc]; simpl in *.
    eexists; simpl.
    + ercompose; eauto.
    + ercompose; eauto.
Qed.
*)
