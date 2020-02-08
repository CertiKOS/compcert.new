(* ********************* *)
(* Author: Yuting Wang   *)
(* Date:   Oct 2, 2019   *)
(* ********************* *)

Require Import Coqlib Integers Values Maps AST.
Require Import Linking Errors LinkingProp.
Require Import Permutation.


(** * Linking of Asm program such that the order of internal definitions is preserved **)

Lemma in_map_incl: forall A B a (l l': list A) (f: A -> B),
    In a (map f l) -> incl l l' -> In a (map f l').
Proof.
  induction l as [|b l].
  - cbn. intros. contradiction.
  - cbn. intros l' f [EQ | IN] INCL.
    + subst. apply in_map. red in INCL. 
      apply INCL. apply in_eq.
    + apply IHl; auto.
      eapply incl_cons_inv; eauto.
Qed.

Lemma filter_incl: forall A f (l: list A), incl (filter f l) l.
Proof. 
  induction l as [|a l]; cbn; intros.
  - red. auto.
  - red. red in IHl.
    intros b H. destruct (f a).
    + inv H. apply in_eq.
      intuition.
    + intuition.
Qed.

Lemma list_norepet_filter_fst_pres: forall A B (l:list (A * B)) f,
    list_norepet (map fst l) -> list_norepet (map fst (filter f l)).
Proof.
  induction l as [|a l].
  - intros. cbn. constructor.
  - intros. cbn in *.
    destruct (f a).
    + cbn. inv H. constructor; auto.
      intros IN. apply H2.         
      eapply in_map_incl; eauto.
      eapply filter_incl; eauto.
    + apply IHl.
      inv H. auto.
Qed.

(** Bunch of properties about Permutation and PTree *)
Lemma NoDup_list_norepet_equiv : forall A (l: list A),
    NoDup l <-> list_norepet l.
Proof.
  induction l as [|a l].
  - split; intros. constructor. constructor.
  - split; intros. 
    + inv H. constructor; auto. rewrite <- IHl. auto.
    + inv H. constructor; auto. rewrite IHl. auto.
Qed.

Lemma Permutation_pres_list_norepet: forall A (l1 l2: list A),
  list_norepet l1 -> Permutation l1 l2 -> list_norepet l2.
Proof.
  intros. rewrite <- NoDup_list_norepet_equiv in *.
  eapply Permutation_NoDup; eauto.
Qed.

Lemma Permutation_NoDup_map: forall A B (f: A -> B) (l1 l2: list A),
    Permutation l1 l2 -> NoDup (map f l1) -> NoDup (map f l2).
Proof.
  intros A B f l1 l2 PERM NODUP.
  apply Permutation_NoDup with (l:= map f l1); eauto.
  apply Permutation_map; auto.
Qed.

Lemma Permutation_list_norepet_map: forall A B (f: A -> B) (l1 l2: list A),
    Permutation l1 l2 -> list_norepet (map f l1) -> list_norepet (map f l2).
Proof.
  intros A B f l1 l2 PERM NORPT.
  rewrite <- NoDup_list_norepet_equiv in *.
  eapply Permutation_NoDup_map; eauto.
Qed.

Lemma Permutation_pres_ptree_get_some: forall A (l1 l2: list (ident * A)) a e,
    list_norepet (map fst l1) ->
    Permutation l1 l2 -> (PTree_Properties.of_list l1) ! a = Some e -> 
    (PTree_Properties.of_list l2) ! a = Some e.
Proof. 
  intros A l1 l2 a e NORPT PERM GET.
  apply PTree_Properties.of_list_norepet; auto.
  eapply Permutation_list_norepet_map; eauto.
  eapply Permutation_in; eauto.
  apply PTree_Properties.in_of_list; auto.
Qed.

Lemma Permutation_pres_ptree_get: forall A (l1 l2: list (ident * A)) a,
    list_norepet (map fst l1) -> 
    Permutation l1 l2 -> 
    (PTree_Properties.of_list l1) ! a = (PTree_Properties.of_list l2) ! a.
Proof. 
  intros A l1 l2 a NORPT1 PERM.
  destruct ((PTree_Properties.of_list l1) ! a) eqn:GET1.
  - symmetry. 
    eapply Permutation_pres_ptree_get_some; eauto.
  - destruct ((PTree_Properties.of_list l2) ! a) eqn:GET2; auto.
    assert (list_norepet (map fst l2)) as NORPT2.
    { eapply Permutation_list_norepet_map; eauto. }
    apply Permutation_sym in PERM.
    generalize (@Permutation_pres_ptree_get_some _ _ _ a a0 NORPT2 PERM GET2).    intros. congruence.
Qed.


Lemma PTree_combine_permutation: forall A B C (f: option A -> option B -> option C) l1 l1' l2 l2',
    f None None = None ->
    Permutation l1 l1' -> Permutation l2 l2' ->
    list_norepet (map fst l1) -> list_norepet (map fst l2) ->
    Permutation
      (PTree.elements
         (PTree.combine f (PTree_Properties.of_list l1) (PTree_Properties.of_list l2)))
      (PTree.elements
         (PTree.combine f (PTree_Properties.of_list l1') (PTree_Properties.of_list l2'))).
Proof.
  intros until l2'.
  intros F PERM1 PERM2 NORPT1 NORPT2.
  apply NoDup_Permutation.
  apply NoDup_map_inv with (f:=fst); auto.
  rewrite NoDup_list_norepet_equiv.
  apply PTree.elements_keys_norepet.
  apply NoDup_map_inv with (f:=fst); auto.
  rewrite NoDup_list_norepet_equiv.
  apply PTree.elements_keys_norepet.
  intros (id, a).
  split; intros IN.
  - apply PTree.elements_complete in IN.
    apply PTree.elements_correct.
    rewrite PTree.gcombine in *; auto.
    rewrite <- (Permutation_pres_ptree_get _ l1 l1'); auto.
    rewrite <- (Permutation_pres_ptree_get _ l2 l2'); auto.
  - apply PTree.elements_complete in IN.
    apply PTree.elements_correct.
    rewrite PTree.gcombine in *; auto.
    rewrite (Permutation_pres_ptree_get _ l1 l1'); auto.
    rewrite (Permutation_pres_ptree_get _ l2 l2'); auto.
Qed.

Lemma PTree_remove_pres_in:
  forall (A : Type) i j (t : PTree.t A) v,
    i <> j -> In (i, v) (PTree.elements t) ->
    In (i, v) (PTree.elements (PTree.remove j t)).
Proof.
  intros A i j t v NEQ IN.
  apply PTree.elements_correct.
  rewrite PTree.gro; eauto.
  apply PTree.elements_complete; auto.
Qed.

Lemma PTree_remove_pres_in':
  forall (A : Type) i j (t : PTree.t A) v,
    In (i, v) (PTree.elements (PTree.remove j t)) ->
    In (i, v) (PTree.elements t).
Proof.
  intros A i j t v IN.
  apply PTree.elements_correct.
  apply PTree.elements_complete in IN.
  destruct (ident_eq i j). subst.
  generalize (PTree.grs j t). intros. congruence.
  erewrite <- PTree.gro; eauto.
Qed.

Lemma PTree_remove_list_pres_incl: forall {A:Type} ids (t:PTree.t A),
    incl (PTree.elements (fold_right (@PTree.remove A) t ids)) (PTree.elements t).
Proof.
  induction ids as [|id ids].
  - cbn [fold_right]. intros. apply incl_refl.
  - cbn [fold_right]. intros.
    eapply incl_tran. 2: eauto.
    red. intros a IN.
    destruct a. apply PTree_remove_pres_in' with id; auto.
Qed.

Lemma PTree_remove_permutation: forall A id (t: PTree.t A) a l,
    list_norepet (map fst ((id, a) :: l)) ->
    t ! id = Some a ->
    Permutation (PTree.elements (PTree.remove id t)) l ->
    Permutation (PTree.elements t) ((id, a) :: l).
Proof.
  intros A id t a l NORPT GET PERM.
  apply NoDup_Permutation.
  apply NoDup_map_inv with (f:=fst).
  rewrite NoDup_list_norepet_equiv.
  apply PTree.elements_keys_norepet.
  apply NoDup_map_inv with (f:=fst).
  rewrite NoDup_list_norepet_equiv. auto.
  intros (id', a').
  split; intros IN.
  - destruct (ident_eq id id').
    + subst.
      apply PTree.elements_complete in IN.
      assert (a = a') by congruence. subst.
      apply in_eq.
    + apply in_cons.
      eapply Permutation_in; eauto.      
      apply PTree_remove_pres_in; auto.
  - destruct (ident_eq id id').
    + subst. inv IN. 
      * inv H. apply PTree.elements_correct; auto.
      * cbn in NORPT. inv NORPT.
        apply (in_map fst) in H. cbn in H.
        contradiction.
    + inv IN. inv H. congruence.
      apply PTree.elements_correct.
      rewrite <- PTree.gro with (j := id); auto.
      apply PTree.elements_complete.
      apply Permutation_sym in PERM.
      eapply Permutation_in; eauto.
Qed.      

Lemma NoDup_ptree_elements: forall A (t: PTree.t A), NoDup (PTree.elements t).
Proof.
  intros.
  apply NoDup_map_inv with (f:=fst).
  rewrite NoDup_list_norepet_equiv.
  apply PTree.elements_keys_norepet.
Qed.

Lemma PTree_remove_in_absurd: forall A id (a:A) (t:PTree.t A),
    ~ In (id, a) (PTree.elements (PTree.remove id t)).
Proof.
  intros.
  intro IN.
  apply PTree.elements_complete in IN.
  generalize (PTree.grs id t). intros. congruence.
Qed. 

Lemma PTree_remove_permutation': forall A id (t: PTree.t A) a,
    t ! id = Some a ->
    Permutation (PTree.elements t) ((id, a) :: (PTree.elements (PTree.remove id t))).
Proof.
  intros.
  apply NoDup_Permutation.
  - apply NoDup_ptree_elements.
  - constructor.
    apply PTree_remove_in_absurd.
    apply NoDup_ptree_elements.
  - intros (id', a').
    split; intros IN.
    + destruct (ident_eq id id').
      * subst.
        apply PTree.elements_complete in IN.
        assert (a = a') by congruence. subst.
        apply in_eq.
      * apply in_cons.
        eapply Permutation_in; eauto.      
        apply PTree_remove_pres_in; auto.
    + inv IN. inv H0. apply PTree.elements_correct; auto.
      eapply PTree_remove_pres_in'; eauto.
Qed.    


(** Extract elements from PTrees in order *)
Fixpoint PTree_extract_elements {A:Type} (ids: list ident) (t: PTree.t A) :=
  match ids with 
  | nil => Some (nil, t)
  | id :: ids' =>
    match PTree_extract_elements ids' t with
    | None => None
    | Some (vals, t') => 
      match t'!id with
      | None => None
      | Some val => 
        Some ((id, val) :: vals, (PTree.remove id t'))
      end
    end
  end.
    

Lemma PTree_extract_elements_app : forall {A} (ids1 ids2: list ident) (t t': PTree.t A) defs,
    PTree_extract_elements (ids1 ++ ids2) t = Some (defs, t') ->
    exists t1 defs1 defs2, PTree_extract_elements ids2 t = Some (defs2, t1) /\
                      PTree_extract_elements ids1 t1 = Some (defs1, t') /\
                      defs = defs1 ++ defs2.
Proof.
  induction ids1 as [|id1 ids1]; cbn.
  - intros ids2 t t' defs EXT.
    do 3 eexists. split; eauto.
  - intros ids2 t t' defs EXT.
    destr_in EXT. destruct p. destr_in EXT. inv EXT.
    edestruct IHids1 as (t1' & defs1' & defs2' &  EXT1 & EXT2 & EQ); eauto. subst.
    do 3 eexists; split; eauto.
    rewrite EXT2. rewrite Heqo0. split; eauto.
Qed.
    

Lemma PTree_extract_elements_permutation : forall {A:Type} (ids: list ident) (t t':PTree.t A) vals,
  PTree_extract_elements ids t = Some (vals, t') ->
  Permutation (PTree.elements t) (vals ++ (PTree.elements t')).
Proof.
  induction ids as [|id ids].
  - cbn. inversion 1. subst. inv H. auto.
  - cbn. intros t t' vals H.
    destr_in H. destruct p. destr_in H. inv H. cbn.
    generalize (IHids _ _ _ Heqo). intros PERM.
    eapply Permutation_trans; eauto.
    assert (Permutation (PTree.elements t0) ((id, a) :: PTree.elements (PTree.remove id t0))).
    { apply PTree_remove_permutation'; auto. }
    eapply Permutation_trans.
    apply Permutation_app_head. exact H.
    apply Permutation_sym. 
    apply Permutation_middle.
Qed.

Lemma PTree_extract_elements_permutation' : forall {A:Type} (ids: list ident) (t t':PTree.t A) vals,
  PTree_extract_elements ids t = Some (vals, t') ->
  Permutation (PTree.elements t) ((PTree.elements t') ++ vals).
Proof.
  intros A ids t t' vals H.
  eapply Permutation_trans.
  eapply PTree_extract_elements_permutation; eauto.
  apply Permutation_app_comm.
Qed.

Lemma PTree_extract_elements_remain: 
  forall {A:Type} ids defs (t t': PTree.t A),
    PTree_extract_elements ids t = Some (defs, t') ->
    t' = fold_right (@PTree.remove A) t ids.
Proof.
  induction ids as [|id ids].
  - cbn. inversion 1. subst. auto.
  - cbn. intros defs t t' EXTR.
    destr_in EXTR. destruct p.
    destr_in EXTR. inv EXTR.
    f_equal. 
    eapply IHids; eauto.
Qed.

Lemma PTree_remove_ids_not_in : forall {A} ids t id a,
  (fold_right (@PTree.remove A) t ids) ! id = Some a -> ~In id ids.
Proof.
  induction ids as [| id' ids].
  - cbn. auto.
  - cbn. intros t id a RM.
    assert (id <> id') as NEQ.
    { intros EQ. subst. rewrite PTree.grs in RM. congruence. }
    intros H. destruct H; subst.
    congruence.
    erewrite PTree.gro in RM; eauto.
    eapply IHids; eauto.
Qed.

Lemma PTree_extract_elements_domain_norepet: forall {A:Type} ids (t:PTree.t A) r,
  PTree_extract_elements ids t = Some r -> list_norepet ids.
Proof.
  induction ids as [|id ids].
  - cbn. intros. inv H. constructor.
  - cbn. intros t r EXT. destr_in EXT. destruct p.
    destr_in EXT. inv EXT. constructor.
    apply PTree_extract_elements_remain in Heqo. subst.
    eapply PTree_remove_ids_not_in; eauto.
    eauto.
Qed.

Lemma PTree_get_remove_not_in: forall {A:Type} ids id (t:PTree.t A) a,
    (fold_right (@PTree.remove A) t ids) ! id = Some a ->
    t ! id = Some a.
Proof.
  induction ids as [|id' ids].
  - intros id t a RM.
    cbn in RM. auto.
  - intros id t a RM.
    generalize (PTree_remove_ids_not_in _ _ _ _ RM); eauto.
    intros IN.
    cbn in RM.
    assert (id <> id').
    { intros EQ. subst. apply IN. apply in_eq. }
    erewrite PTree.gro in RM; auto.
Qed.

Lemma PTree_get_remove_not_in_eq: forall {A:Type} ids id (t:PTree.t A),
    ~In id ids ->
    (fold_right (@PTree.remove A) t ids) ! id = t !id.
Proof.
  induction ids as [|id' ids].
  - intros id t IN.
    cbn. auto.
  - intros id t IN.
    assert (id <> id').
    { intros EQ. subst. apply IN. apply in_eq. }
    cbn. erewrite PTree.gro; eauto.
    eapply IHids; eauto.
    intros IN'. apply IN. apply in_cons. auto.
Qed.

Definition PTree_combine_ids_defs_match {A B C} 
           (t1:PTree.t A) (t2: PTree.t B) 
           (f: option A -> option B -> option C)
           (ids: list ident) (defs: list (ident * C)) :=
  Forall2 (fun (id : positive) '(id', def) => id = id' /\ f t1 ! id t2 ! id = Some def)
    ids defs.
  

Lemma PTree_combine_ids_defs_match_det: 
  forall {A B C} (t1:PTree.t A) (t2:PTree.t B) 
    (f:option A -> option B -> option C) ids l1 l2,
    PTree_combine_ids_defs_match t1 t2 f ids l1 ->
    PTree_combine_ids_defs_match t1 t2 f ids l2 ->
    l1 = l2.
Proof.
  induction ids as [|id ids].
  - intros l1 l2 MATCH1 MATCH2.
    inv MATCH1. inv MATCH2. auto.
  - intros l1 l2 MATCH1 MATCH2.
    inv MATCH1. inv MATCH2.
    destruct y, y0. inv H1. inv H2.
    f_equal. congruence.
    eauto.
Qed.

Lemma PTree_elements_combine_incl:
  forall {A B C: Type} l
    (f : option A -> option B -> option C)
    (t1: PTree.t A)
    (t2: PTree.t B),
  f None None = None ->
  incl l (PTree.elements (PTree.combine f t1 t2)) ->
  PTree_combine_ids_defs_match t1 t2 f (map fst l) l.
Proof.
  induction l as [|d l].
  - cbn. intros. red. auto.
  - cbn. 
    intros f t1 t2 FN EQ.
    destruct d as [id def].
    red. cbn. constructor.
    + split; auto.
      erewrite <- PTree.gcombine; eauto.
      apply PTree.elements_complete. 
      red in EQ. apply EQ. apply in_eq.
    + apply IHl; auto.
      eapply incl_cons_inv; eauto.
Qed.

Lemma PTree_elements_combine:
  forall {A B C: Type} 
    (f : option A -> option B -> option C)
    (t1: PTree.t A)
    (t2: PTree.t B),
  f None None = None ->
  PTree_combine_ids_defs_match t1 t2 f 
     (map fst (PTree.elements (PTree.combine f t1 t2))) 
     (PTree.elements (PTree.combine f t1 t2)).
Proof.
  intros. eapply PTree_elements_combine_incl; eauto.
  apply incl_refl.
Qed.


Lemma PTree_extract_elements_combine_match: 
  forall {A:Type} ids defs f (t1 t2 t': PTree.t A),
    f None None = None ->
    PTree_extract_elements ids (PTree.combine f t1 t2) = Some (defs, t') ->
    PTree_combine_ids_defs_match t1 t2 f ids defs.
Proof.
  induction ids as [|id ids].
  - inversion 2. subst.
    constructor.
  - intros defs f t1 t2 t' FN EXT.
    generalize (PTree_extract_elements_domain_norepet _ _ _ EXT).
    intros NORPT. cbn in *.
    destr_in EXT. destruct p as (vals & t'').
    destr_in EXT. inv EXT. constructor.
    + split; auto.
      inv NORPT.
      generalize (PTree_extract_elements_remain _ _ _ _ Heqo).
      intros. subst.
      assert ((PTree.combine f t1 t2)!id = Some a). 
      { eapply PTree_get_remove_not_in; eauto. }
      erewrite PTree.gcombine in H; eauto.
    + inv NORPT.
      eapply IHids; eauto.
Qed.


Lemma PTree_extract_elements_remove_not_in: forall {A} ids (t:PTree.t A) id r,
  PTree_extract_elements ids (PTree.remove id t) = Some r ->
  ~In id ids.
Proof.
  induction ids as [| id' ids].
  - cbn. auto.
  - cbn. intros t id r EXT.
    destr_in EXT. destruct p. destr_in EXT. inv EXT.
    generalize (IHids _ _ _ Heqo). intros NIN.
    intros H. destruct H; auto.
    subst.
    apply PTree_extract_elements_remain in Heqo. subst.
    erewrite PTree_get_remove_not_in_eq in Heqo0; eauto.
    rewrite PTree.grs in Heqo0. congruence.
Qed.
  

Lemma PTree_extract_elements_remove_pres: forall {A} id ids (t t':PTree.t A) defs,
  PTree_extract_elements ids (PTree.remove id t) = Some (defs, t') ->
  exists t'', PTree_extract_elements ids t = Some (defs, t'').
Proof.
  induction ids as [| id' ids].
  - intros t t' defs EXT.
    cbn in EXT. inv EXT. cbn. eauto.
  - intros t t' defs EXT.
    generalize (PTree_extract_elements_remove_not_in _ _ _ _ EXT).
    intros NIN.
    generalize (PTree_extract_elements_domain_norepet _ _ _ EXT).
    intros NORPT.
    assert (~In id ids) as NIN'.
    { intros IN. apply NIN. apply in_cons. auto. }
    cbn in EXT. destr_in EXT. destruct p.
    destr_in EXT. inv EXT. inv NORPT.
    generalize (IHids _ _ _  Heqo).
    intros (t'' & EXT').
    cbn. rewrite EXT'.
    apply PTree_extract_elements_remain in EXT'.
    subst.
    erewrite PTree_get_remove_not_in_eq; eauto.
    apply PTree_extract_elements_remain in Heqo.
    subst. 
    erewrite PTree_get_remove_not_in_eq in Heqo0; eauto.
    assert (id <> id').
    { intros EQ. subst. apply NIN. apply in_eq. }
    erewrite <- PTree.gro; eauto.
    rewrite Heqo0. eauto.
Qed.


Lemma PTree_extract_elements_remove_list_pres: forall {A} ids' ids (t t':PTree.t A) defs,
  PTree_extract_elements ids (fold_right (@PTree.remove A) t ids') = Some (defs, t') ->
  exists t'', PTree_extract_elements ids t = Some (defs, t'').
Proof.
  induction ids' as [|id' ids'].
  - cbn. intros ids t t' defs EXT. eauto.
  - cbn. intros ids t t' defs EXT.
    apply PTree_extract_elements_remove_pres in EXT.
    destruct EXT as (t'' & EXT).
    eauto.
Qed.


Lemma Forall2_in_map: 
  forall {A B} (l:list B) (a:B) (R: A -> B -> Prop) (f:B -> A),
    In a l -> Forall2 R (map f l) l -> R (f a) a.
Proof.
  induction l as [|e l].
  - intros a R f IN FA.
    inv IN.
  - intros a R f IN FA. cbn in *.
    inv IN. subst.
    + inv FA. auto.
    + inv FA. apply IHl; auto.
Qed.
  
Lemma PTree_combine_ids_defs_match_incl : 
  forall {A B C} (t1:PTree.t A) (t2:PTree.t B) f (l1 l2: list (ident * C)),
    PTree_combine_ids_defs_match t1 t2 f (map fst l1) l1 ->
    incl l2 l1 ->
    PTree_combine_ids_defs_match t1 t2 f (map fst l2) l2.
Proof.
  induction l2 as [|e l2].
  - cbn. intros. red. auto.
  - cbn. intros MATCH INCL.
    generalize (incl_cons_inv INCL). intros INCL'.
    apply Forall2_cons.
    + destruct e. cbn. split; auto.
      red in MATCH. 
      red in INCL.
      assert (In (i,c) l1) as IN.
      { apply INCL. apply in_eq. }
      generalize (Forall2_in_map l1 (i,c) _ fst IN MATCH).
      cbn. intros (EQ & RS). auto.
    + apply IHl2; auto.
Qed.


Lemma PTree_extract_elements_combine_remain_match: 
  forall {A:Type} ids defs f (t1 t2 t': PTree.t A),
    f None None = None ->
    PTree_extract_elements ids (PTree.combine f t1 t2) = Some (defs, t') ->
    PTree_combine_ids_defs_match t1 t2 f 
                                 (map fst (PTree.elements t'))
                                 (PTree.elements t').
Proof.
  intros A ids defs f t1 t2 t' FN EXT.
  generalize (PTree_extract_elements_remain _ _ _ _ EXT); eauto.
  intros EQ. subst.
  generalize (PTree_elements_combine _ t1 t2 FN); eauto.
  intros MATCH.
  eapply PTree_combine_ids_defs_match_incl; eauto.
  apply PTree_remove_list_pres_incl.
Qed.

Lemma PTree_combine_ids_defs_match_app: 
  forall {A B C} (t1: PTree.t A) (t2: PTree.t B) 
    (f:option A -> option B -> option C) ids1 defs1 ids2 defs2,
    PTree_combine_ids_defs_match t1 t2 f ids1 defs1 ->
    PTree_combine_ids_defs_match t1 t2 f ids2 defs2 ->
    PTree_combine_ids_defs_match t1 t2 f (ids1 ++ ids2) (defs1 ++ defs2).
Proof.
  induction ids1 as [|id1 ids1].
  - cbn. inversion 1. subst. cbn. auto.
  - cbn. inversion 1. subst. destruct y. 
    inv H2. inv H. inv H5. 
    intros MATCH.
    cbn. red. constructor.
    split; auto.
    eapply IHids1; eauto.
Qed.

Lemma PTree_combine_ids_defs_match_symm: 
  forall {A B} (t1 t2: PTree.t A) (f: option A -> option A -> option B) ids entries,
    (forall a b, f a b = f b a) ->
    PTree_combine_ids_defs_match t1 t2 f ids entries ->
    PTree_combine_ids_defs_match t2 t1 f ids entries.
Proof.
  induction ids as [|id ids].
  - intros. inv H0. red. auto.
  - intros. inv H0. destruct y. destruct H3; subst.
    red. constructor.
    split; auto. rewrite H. auto.
    eapply IHids; eauto.
Qed.

(** The main proof begins *)

Section WITHFV.

Context {F V: Type}.
Context {LF: Linker F}.
Context {LV: Linker V}.

Variable is_fun_internal: F -> bool.

Lemma list_norepet_internal_ids: forall (p: program F V) ,
    list_norepet (map fst (prog_defs p)) ->
    list_norepet (collect_internal_def_ids is_fun_internal p).
Proof.
  intros. 
  unfold collect_internal_def_ids.
  unfold filter_internal_defs.
  apply list_norepet_filter_fst_pres; auto.
Qed.


Definition link_prog_ordered p1 p2 :=
  let dm1 := prog_option_defmap p1 in
  let dm2 := prog_option_defmap p2 in
  if ident_eq p1.(prog_main) p2.(prog_main) 
     && list_norepet_dec ident_eq (map fst (prog_defs p1))
     && list_norepet_dec ident_eq (map fst (prog_defs p2)) 
     && PTree_Properties.for_all dm1 (link_prog_check p1 p2) then
    let t := PTree.combine link_prog_merge dm1 dm2 in
    let ids1 := collect_internal_def_ids is_fun_internal p1 in
    let ids2 := collect_internal_def_ids is_fun_internal p2 in
    match PTree_extract_elements (ids1 ++ ids2) t with
    | None => None
    | Some (defs, t') => 
      Some {| prog_main := p1.(prog_main);
              prog_public := p1.(prog_public) ++ p2.(prog_public);
              prog_defs := PTree.elements t' ++ defs |}
    end
  else
    None.

Lemma link_prog_ordered_inv: forall(p1 p2 p:program F V),
    link_prog_ordered p1 p2 = Some p ->
    list_norepet (map fst (AST.prog_defs p1)) /\
    list_norepet (map fst (AST.prog_defs p2)).
Proof.
  intros p1 p2 p LINK.
  unfold link_prog_ordered in LINK.
  destr_in LINK; try congruence.
  repeat rewrite andb_true_iff in Heqb.
  destruct Heqb as [[[IDEQ NRPT1] NRPT2] CHK].
  destruct list_norepet_dec; try discriminate.
  destruct list_norepet_dec; try discriminate.
  auto.
Qed.

End WITHFV.

Instance Linker_prog_ordered (F V: Type) {LV: Linker V} : Linker (program (fundef F) V) := {
  link a b := link_prog_ordered is_fundef_internal a b;
  linkorder a b := True;
}.
Proof.
  auto.
  auto.
  auto.
Defined.

Global Opaque Linker_prog_ordered.



Lemma PTree_extract_elements_pres_get : forall A id ids defs (t t':PTree.t A),
    ~In id ids ->
    PTree_extract_elements ids t = Some (defs, t') ->
    t ! id = t' ! id.
Proof.
  induction ids as [|id1 ids].
  - cbn. intros. inv H0. auto.
  - cbn. intros defs t t' NIN MATCH.
    apply Decidable.not_or in NIN. destruct NIN as [NEQ NIN].
    destr_in MATCH. destruct p. destr_in MATCH.
    inv MATCH.
    erewrite PTree.gro; eauto.
Qed.

Lemma PTree_extract_elements_exists: forall A ids (t: PTree.t A),
    list_norepet ids ->
    incl ids (map fst (PTree.elements t)) ->
    exists defs t', PTree_extract_elements ids t = Some (defs, t').
Proof.
  induction ids as [|id ids].
  - cbn. intros. eauto.
  - cbn. 
    intros t NORPT INCL. inv NORPT.
    red in INCL.
    edestruct IHids as (defs1 & t1' & EXT); eauto.
    red. intuition.
    rewrite EXT.
    assert (In id (map fst (PTree.elements t))) as IN by intuition.
    edestruct PTree_Properties.of_list_dom as (v & GET); eauto.
    rewrite PTree_Properties.of_list_elements in GET.
    erewrite <- PTree_extract_elements_pres_get; eauto.
    rewrite GET. eauto.
Qed.

Lemma collect_internal_def_ids_inv: forall {F V} (p: program (fundef F) V) id,
    list_norepet (map fst (prog_defs p)) ->
    In id (collect_internal_def_ids is_fundef_internal p) ->
    exists def, (prog_option_defmap p)!id = Some def /\ 
           is_def_internal is_fundef_internal def = true.
Proof.
  intros F V p id NORPT IN.
  unfold prog_option_defmap.
  unfold collect_internal_def_ids in IN.
  apply list_in_map_inv in IN.
  destruct IN as ((id', def) & EQ & IN). subst.
  unfold filter_internal_defs in IN.
  rewrite filter_In in IN.
  destruct IN as (IN & DEF).
  eexists; split; eauto.
  cbn.
  apply PTree_Properties.of_list_norepet; eauto.
Qed.

Existing Instance Linker_option.
Definition prog_linkable {F V} {LF: Linker F} {LV: Linker V} (p1 p2: program F V) :=
  forall (id : positive) (gd1 gd2 : option (globdef F V)),
    (prog_option_defmap p1) ! id = Some gd1 ->
    (prog_option_defmap p2) ! id = Some gd2 ->
    In id (prog_public p1) /\ In id (prog_public p2) /\ (exists gd, link gd1 gd2 = Some gd).


Lemma link_prog_linkable:
  forall {F V} {LF: Linker F} {LV: Linker V} (p1 p2 p:program F V),
    link_prog p1 p2 = Some p ->
    prog_linkable p1 p2.
Proof.
  intros.
  generalize (link_prog_inv _ _ _ H).
  intros (MAINEQ & NORPT1 & NORPT2 & PROP & P).
  red. auto.
Qed.


Lemma link_prog_merge_some1: 
  forall {F V} {LF: Linker F} {LV: Linker V} a (def: option (globdef F V)) (p1 p2: program F V),
    prog_linkable p1 p2 ->
    (prog_option_defmap p1)!a = Some def ->
    exists def', link_prog_merge (Some def) ((PTree_Properties.of_list (prog_defs p2)) ! a) = Some def'.
Proof.
  intros F V LF LV a def p1 p2 LINKABLE GET.
  cbn. unfold link_option.
  destr; eauto.
  red in LINKABLE.
  generalize (LINKABLE _ _ _ GET Heqo).
  intros (IN1 & IN2 & (gd & LINK)). 
  destr; eauto.
Qed.


Lemma link_prog_merge_pres_get1: forall {F V} {LF: Linker F} {LV: Linker V} a (def: option (globdef F V)) (p1 p2: program F V),
    prog_linkable p1 p2 ->
    (prog_option_defmap p1) ! a = Some def ->
    exists def', 
      (PTree.combine link_prog_merge (prog_option_defmap p1)
                     (prog_option_defmap p2)) ! a = Some def'.
Proof.
  intros F V LF LV a def p1 p2 CHECK GET.
  unfold prog_option_defmap in *.
  rewrite PTree.gcombine; auto.
  rewrite GET.
  eapply link_prog_merge_some1; eauto.
Qed.


Lemma link_prog_merge_some2: 
  forall {F V} {LF: Linker F} {LV: Linker V} a (def: option (globdef F V)) (p1 p2: program F V),
    prog_linkable p1 p2 ->
    (prog_option_defmap p2)!a = Some def ->
    exists def', link_prog_merge ((PTree_Properties.of_list (prog_defs p1)) ! a) (Some def) = Some def'.
Proof.
  intros F V LF LV a def p1 p2 LINKABLE GET.
  cbn. 
  red in LINKABLE.
  unfold link_prog_merge.
  destr; eauto.
  generalize (LINKABLE _ _ _ Heqo GET).
  intros (IN1 & IN2 & (gd & LINK)). 
  eauto.
Qed.

Lemma link_prog_merge_pres_get2: forall {F V} {LF: Linker F} {LV: Linker V} a (def: option (globdef F V)) (p1 p2: program F V),
    prog_linkable p1 p2 ->
    (prog_option_defmap p2) ! a = Some def ->
    exists def', 
      (PTree.combine link_prog_merge (prog_option_defmap p1)
                     (prog_option_defmap p2)) ! a = Some def'.
Proof.
  intros F V LF LV a def p1 p2 CHECK GET.
  unfold prog_option_defmap in *.
  rewrite PTree.gcombine; auto.
  rewrite GET.
  eapply link_prog_merge_some2; eauto.
Qed.


Existing Instance Linker_option.
Existing Instance Linker_fundef.

Lemma link_internal_fundefs_none: forall F (f1 f2:fundef F),
    is_fundef_internal f1 = true ->
    is_fundef_internal f2 = true ->
    link_fundef f1 f2 = None.
Proof.
  intros F f1 f2 INT1 INT2.
  destruct f1, f2.
  - cbn. auto.
  - cbn in *. congruence.
  - cbn in *. congruence.
  - cbn in *. congruence.
Qed.

Lemma link_internal_varinit_none: forall {V} {LV: Linker V} (v1 v2:globvar V),
    is_var_internal v1 = true ->
    is_var_internal v2 = true ->
    link_varinit (gvar_init v1) (gvar_init v2) = None.
Proof.
  intros V LV v1 v2 INT1 INT2.
  unfold link_varinit.
  unfold is_var_internal in *.
  destr_in INT1.
  destr_in INT2.
Qed.


Lemma link_internal_vardefs_none: forall {V} {LV: Linker V} (v1 v2:globvar V),
    is_var_internal v1 = true ->
    is_var_internal v2 = true ->
    link_vardef v1 v2 = None.
Proof.
  Local Transparent Linker_varinit.
  intros V LV v1 v2 INT1 INT2.
  unfold link_vardef.
  destr. destr. destr.
  generalize (link_internal_varinit_none _ _ INT1 INT2).
  cbn in *.
  intros. congruence.
Qed.

Lemma link_int_defs_none: forall {F V} {LV: Linker V} (def1 def2: option (globdef (fundef F) V)),
    is_def_internal is_fundef_internal def1 = true ->
    is_def_internal is_fundef_internal def2 = true ->
    link def1 def2 = None.
Proof.
  Local Transparent Linker_option Linker_def Linker_fundef Linker_vardef.
  intros F V LV def1 def2 INT1 INT2.
  cbn. unfold link_option.
  unfold is_def_internal in *.
  destr_in INT1. destr_in INT2.
  destr_in INT1; destr_in INT2; subst.
  - unfold link. cbn.   
    erewrite link_internal_fundefs_none; eauto.
  - cbn. 
    erewrite link_internal_vardefs_none; eauto.
Qed.

Lemma extract_defs_exists: 
  forall {F V: Type} {LV:Linker V} 
    (p1 p2 p: program (fundef F) V) t ids1 ids2,
    prog_linkable p1 p2 ->
    list_norepet (map fst (prog_defs p1)) ->
    list_norepet (map fst (prog_defs p2)) ->
    ids1 = collect_internal_def_ids is_fundef_internal p1 ->
    ids2 = collect_internal_def_ids is_fundef_internal p2 ->
    t = PTree.combine link_prog_merge 
                      (prog_option_defmap p1) 
                      (prog_option_defmap p2) ->
    exists defs t',
      PTree_extract_elements (ids1 ++ ids2) t = Some (defs, t').
Proof.
  intros F V LV p1 p2 p t ids1 ids2 PROP NORPT1 NORPT2 IDS1 IDS2 T. subst.
  eapply PTree_extract_elements_exists; eauto.
  rewrite list_norepet_app.
  repeat split.
  eapply list_norepet_internal_ids; eauto.
  eapply list_norepet_internal_ids; eauto.
  - red.
    intros x y IN1 IN2 EQ. subst.
    generalize (collect_internal_def_ids_inv _ _ NORPT1 IN1).
    intros (def1 & GET1 & INT1).
    generalize (collect_internal_def_ids_inv _ _ NORPT2 IN2).
    intros (def2 & GET2 & INT2).
    edestruct PROP as (PUB1 & PUB2 & (gd & LINK')); eauto.        
    assert (link def1 def2 = None) by (apply link_int_defs_none; auto).
    congruence.
  - apply incl_app.
    + red. intros.
      generalize (collect_internal_def_ids_inv _ _ NORPT1 H).
      intros (def & GET & INT).
      rewrite in_map_iff.
      generalize (link_prog_merge_pres_get1 _ _ _ p2 PROP GET). 
      intros (def' & COMB).
      exists (a, def'). split; auto.
      apply PTree.elements_correct. auto. 
    + red. intros.
      generalize (collect_internal_def_ids_inv _ _ NORPT2 H).
      intros (def & GET & INT).
      rewrite in_map_iff.
      generalize (link_prog_merge_pres_get2 _ _ p1 p2 PROP GET). 
      intros (def' & COMB).
      exists (a, def'). split; auto.
      apply PTree.elements_correct. auto. 
Qed.    


Local Transparent Linker_prog_ordered.

Lemma prog_linkable_permutation: 
  forall {F V} {LF: Linker F} {LV: Linker V}
    (p1 p2 tp1 tp2 p: program F V),
    link p1 p2 = Some p ->
    prog_public p1 = prog_public tp1 ->
    prog_public p2 = prog_public tp2 ->
    Permutation (prog_defs p1) (prog_defs tp1) ->
    Permutation (prog_defs p2) (prog_defs tp2) ->
    prog_linkable tp1 tp2.
Proof.
  intros F V LF LV p1 p2 tp1 tp2 p LINK PUB1 PUB2 PERM1 PERM2.
  generalize (link_prog_inv _ _ _ LINK).
  intros (MAINEQ & NORPT1 & NORPT2 & LINKABLE & P). clear P.
  intros id gd1 gd2 GET1 GET2.
  unfold prog_option_defmap in *.
  rewrite <- (Permutation_pres_ptree_get _ _ _ _ NORPT1  PERM1) in GET1; eauto.
  rewrite <- (Permutation_pres_ptree_get _ _ _ _ NORPT2  PERM2) in GET2; eauto.
  edestruct LINKABLE as (IN1 & IN2 & (gd & LINK')); eauto.
  repeat (split; eauto).
  rewrite <- PUB1. auto.
  rewrite <- PUB2. auto.
Qed.

Lemma link_prog_ordered_inv': 
  forall {F V} {LV: Linker V} 
    (p1 p2 p: AST.program (AST.fundef F) V),
    link_prog_ordered is_fundef_internal p1 p2 = Some p ->
    exists p', 
      link_prog p1 p2 = Some p' /\
      Permutation (AST.prog_defs p) (AST.prog_defs p').
Proof.
  intros F V LV p1 p2 p LINK.
  unfold link_prog_ordered in LINK.
  destr_in LINK. 
  destr_in LINK.
  destruct p0 as (defs3 & t'). inv LINK. cbn.
  eexists. split.
  - unfold link_prog.
    rewrite Heqb. reflexivity.
  - cbn.
    apply Permutation_sym.
    eapply PTree_extract_elements_permutation'; eauto.
Qed.
