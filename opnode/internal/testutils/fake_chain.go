package testutils

import (
	"context"
	"errors"
	"math/big"

	"github.com/ethereum/go-ethereum"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/log"

	"github.com/ethereum-optimism/optimistic-specs/opnode/eth"
	"github.com/ethereum-optimism/optimistic-specs/opnode/l2"
	"github.com/ethereum-optimism/optimistic-specs/opnode/rollup"
)

func FakeGenesis(l1 rune, l2 rune, l1GenesisNumber int) rollup.Genesis {
	return rollup.Genesis{
		L1: fakeID(l1, uint64(l1GenesisNumber)),
		L2: fakeID(l2, 0),
	}
}

func fakeID(id rune, num uint64) eth.BlockID {
	var h common.Hash
	copy(h[:], string(id))
	return eth.BlockID{Hash: h, Number: uint64(num)}
}

func fakeL1Block(self rune, parent rune, num uint64) eth.L1BlockRef {
	var parentID eth.BlockID
	if num != 0 {
		parentID = fakeID(parent, num-1)
	}
	id := fakeID(self, num)
	return eth.L1BlockRef{Hash: id.Hash, Number: id.Number, ParentHash: parentID.Hash}
}

func fakeL2Block(self rune, parent rune, l1parent eth.BlockID, num uint64) eth.L2BlockRef {
	var parentID eth.BlockID
	if num != 0 {
		parentID = fakeID(parent, num-1)
	}
	id := fakeID(self, num)

	return eth.L2BlockRef{Hash: id.Hash, Number: id.Number, ParentHash: parentID.Hash, L1Origin: l1parent}
}

func chainL1(offset uint64, ids string) (out []eth.L1BlockRef) {
	var prevID rune
	for i, id := range ids {
		out = append(out, fakeL1Block(id, prevID, offset+uint64(i)))
		prevID = id
	}
	return
}

func chainL2(offset int, l1 []eth.L1BlockRef, ids string) (out []eth.L2BlockRef) {
	var prevID rune
	for i, id := range ids {
		out = append(out, fakeL2Block(id, prevID, l1[i+int(offset)].ID(), uint64(i)))
		prevID = id
	}
	return
}

func NewFakeChainSource(l1 []string, l2 []string, l1GenesisNumber int, log log.Logger) *FakeChainSource {
	var l1s [][]eth.L1BlockRef
	for _, l1string := range l1 {
		l1s = append(l1s, chainL1(0, l1string))
	}
	var l2s [][]eth.L2BlockRef
	for i, l2string := range l2 {
		l2s = append(l2s, chainL2(l1GenesisNumber, l1s[i], l2string))
	}
	return &FakeChainSource{
		l1s: l1s,
		l2s: l2s,
		log: log,
	}
}

// FakeChainSource implements the ChainSource interface with the ability to control
// what the head block is of the L1 and L2 chains. In addition, it enables re-orgs
// to easily be implemented
type FakeChainSource struct {
	l1reorg int                // Index of the L1 chain to be operating on
	l2reorg int                // Index of the L2 chain to be operating on
	l1head  int                // Head block of the L1 chain
	l2head  int                // Head block of the L2 chain
	l1s     [][]eth.L1BlockRef // l1s[reorg] is the L1 chain in that specific re-org configuration
	l2s     [][]eth.L2BlockRef // l2s[reorg] is the L2 chain in that specific re-org configuration
	log     log.Logger
}

func (m *FakeChainSource) L1Range(ctx context.Context, base eth.BlockID, max uint64) ([]eth.BlockID, error) {
	var out []eth.BlockID
	found := false
	for i, b := range m.l1s[m.l1reorg] {
		if found && uint64(len(out)) < max {
			out = append(out, b.ID())
		}
		if b.ID() == base {
			found = true
		}
		if i == m.l1head {
			if found {
				return out, nil
			} else {
				return nil, ethereum.NotFound
			}
		}
	}
	return nil, ethereum.NotFound
}

func (m *FakeChainSource) L1BlockRefByNumber(ctx context.Context, l1Num uint64) (eth.L1BlockRef, error) {
	m.log.Trace("L1BlockRefByNumber", "l1Num", l1Num, "l1Head", m.l1head, "reorg", m.l1reorg)
	if l1Num > uint64(m.l1head) {
		return eth.L1BlockRef{}, ethereum.NotFound
	}
	return m.l1s[m.l1reorg][l1Num], nil
}

func (m *FakeChainSource) L1BlockRefByHash(ctx context.Context, l1Hash common.Hash) (eth.L1BlockRef, error) {
	m.log.Trace("L1BlockRefByHash", "l1Hash", l1Hash, "l1Head", m.l1head, "reorg", m.l1reorg)
	for i, bl := range m.l1s[m.l1reorg] {
		if bl.Hash == l1Hash {
			return m.L1BlockRefByNumber(ctx, uint64(i))
		}
	}
	return eth.L1BlockRef{}, ethereum.NotFound
}

func (m *FakeChainSource) L1HeadBlockRef(ctx context.Context) (eth.L1BlockRef, error) {
	m.log.Trace("L1HeadBlockRef", "l1Head", m.l1head, "reorg", m.l1reorg)
	l := len(m.l1s[m.l1reorg])
	if l == 0 {
		return eth.L1BlockRef{}, ethereum.NotFound
	}
	return m.l1s[m.l1reorg][m.l1head], nil
}

func (m *FakeChainSource) L2BlockRefByNumber(ctx context.Context, l2Num *big.Int) (eth.L2BlockRef, error) {
	m.log.Trace("L2BlockRefByNumber", "l2Num", l2Num, "l2Head", m.l2head, "reorg", m.l2reorg)
	if len(m.l2s[m.l2reorg]) == 0 {
		panic("bad test, no l2 chain")
	}
	if l2Num == nil {
		return m.l2s[m.l2reorg][m.l2head], nil
	}
	i := int(l2Num.Int64())
	if i > m.l2head {
		return eth.L2BlockRef{}, ethereum.NotFound
	}
	return m.l2s[m.l2reorg][i], nil
}

func (m *FakeChainSource) L2BlockRefByHash(ctx context.Context, l2Hash common.Hash) (eth.L2BlockRef, error) {
	m.log.Trace("L2BlockRefByHash", "l2Hash", l2Hash, "l2Head", m.l2head, "reorg", m.l2reorg)
	for i, bl := range m.l2s[m.l2reorg] {
		if bl.Hash == l2Hash {
			return m.L2BlockRefByNumber(ctx, big.NewInt(int64(i)))
		}
	}
	return eth.L2BlockRef{}, ethereum.NotFound
}

func (m *FakeChainSource) ForkchoiceUpdate(ctx context.Context, state *l2.ForkchoiceState, attr *l2.PayloadAttributes) (*l2.ForkchoiceUpdatedResult, error) {
	m.log.Trace("ForkchoiceUpdate", "newHead", state.HeadBlockHash, "l2Head", m.l2head, "reorg", m.l2reorg)
	m.l2reorg++
	if m.l2reorg >= len(m.l2s) {
		panic("No more re-org chains available")
	}
	for i, bl := range m.l2s[m.l2reorg] {
		if bl.Hash == state.HeadBlockHash {
			m.l2head = i
			return nil, nil
		}
	}
	return nil, errors.New("unable to set new head")
}

func (m *FakeChainSource) ReorgL1() {
	m.log.Trace("Reorg L1", "new_reorg", m.l1reorg+1, "old_reorg", m.l1reorg)
	m.l1reorg++
	if m.l1reorg >= len(m.l1s) {
		panic("No more re-org chains available")
	}
}

func (m *FakeChainSource) SetL2Head(head int) eth.L2BlockRef {
	m.log.Trace("Set L2 head", "new_head", head, "old_head", m.l2head)
	m.l2head = head
	if m.l2head >= len(m.l2s[m.l2reorg]) {
		panic("Cannot advance L2 past end of chain")
	}
	return m.l2s[m.l2reorg][m.l2head]
}

func (m *FakeChainSource) AdvanceL1() eth.L1BlockRef {
	m.log.Trace("Advance L1", "new_head", m.l1head+1, "old_head", m.l1head)
	m.l1head++
	if m.l1head >= len(m.l1s[m.l1reorg]) {
		panic("Cannot advance L1 past end of chain")
	}
	return m.l1s[m.l1reorg][m.l1head]
}

func (m *FakeChainSource) L1Head() eth.L1BlockRef {
	m.log.Trace("L1 Head", "head", m.l1head)
	return m.l1s[m.l1reorg][m.l1head]
}
