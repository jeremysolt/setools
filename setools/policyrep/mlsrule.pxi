# Copyright 2014, 2016, Tresys Technology, LLC
# Copyright 2016-2017, Chris PeBenito <pebenito@ieee.org>
#
# This file is part of SETools.
#
# SETools is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as
# published by the Free Software Foundation, either version 2.1 of
# the License, or (at your option) any later version.
#
# SETools is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with SETools.  If not, see
# <http://www.gnu.org/licenses/>.
#
import itertools

#
# MLS rule factory functions
#
cdef inline MLSRule mls_rule_factory_iter(SELinuxPolicy policy, QpolIteratorItem symbol):
    """Factory function variant for iterating over MLSRule objects."""
    return mls_rule_factory(policy, <const qpol_range_trans_t *> symbol.obj)


cdef inline MLSRule mls_rule_factory(SELinuxPolicy policy, const qpol_range_trans_t *symbol):
    """Factory function for creating MLSRule objects."""
    r = MLSRule()
    r.policy = policy
    r.handle = symbol
    return r


#
# Expanded MLS rule factory function
#
cdef inline ExpandedMLSRule expanded_mls_rule_factory(MLSRule original, source, target):
    """
    Factory function for creating expanded MLS rules.

    original    The MLS rule the expanded rule originates from.
    source      The source type of the expanded rule.
    target      The target type of the expanded rule.
    """
    r = ExpandedMLSRule()
    r.policy = original.policy
    r.handle = original.handle
    r.source = source
    r.target = target
    r.origin = original
    return r


class MLSRuletype(PolicyEnum):

    """An enumeration of MLS rule types."""

    range_transition = 1


cdef class MLSRule(PolicyRule):

    """An MLS rule."""

    cdef:
        sepol.range_trans_t *handle
        readonly object ruletype

    def __init__(self):
        self.ruletype = MLSRuletype.range_transition

    def __str__(self):
        return "{0.ruletype} {0.source} {0.target}:{0.tclass} {0.default};".format(self)

    def _eq(self, MLSRule other):
        """Low-level equality check (C pointers)."""
        return self.handle == other.handle

    @property
    def source(self):
        """The rule's source type/attribute."""
        return type_or_attr_factory(self.policy, self.policy.handle.p.p.type_val_to_struct[self.handle.source_type - 1])

    @property
    def target(self):
        """The rule's target type/attribute."""
        return type_or_attr_factory(self.policy, self.policy.handle.p.p.type_val_to_struct[self.handle.target_type - 1])

    @property
    def tclass(self):
        """The rule's object class."""
        return ObjClass.factory(self.policy, self.policy.handle.p.p.class_val_to_struct[self.handle.target_class - 1])

    @property
    def default(self):
        """The rule's default range."""
        cdef sepol.mls_range_t *default_range
        default_range = <sepol.mls_range_t *> hashtab_search(self.policy.handle.p.p.range_tr,
                                                             <sepol.hashtab_key_t> self.handle)
        return Range.factory(self.policy, default_range)

    def expand(self):
        """Expand the rule into an equivalent set of rules without attributes."""
        for s, t in itertools.product(self.source.expand(), self.target.expand()):
            yield expanded_mls_rule_factory(self, s, t)


cdef class ExpandedMLSRule(MLSRule):

    """An expanded MLS rule."""

    cdef:
        public object source
        public object target
        public object origin

    def __hash__(self):
        try:
            cond = self.conditional
            cond_block = self.conditional_block
        except RuleNotConditional:
            cond = None
            cond_block = None

        return hash("{0.ruletype}|{0.source}|{0.target}|{0.tclass}|{1}|{2}".format(
            self, cond, cond_block))

    def __lt__(self, other):
        return str(self) < str(other)
