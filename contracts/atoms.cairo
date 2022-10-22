%lang starknet

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.memcpy import memcpy

from contracts.constants import Grid, ns_atoms, ns_atom_faucets

from contracts.events import Check

struct AtomState {
    id: felt,
    type: felt,
    status: felt,
    index: Grid,
    possessed_by: felt,
}

struct AtomFaucetState {
    id: felt,
    type: felt,
    index: Grid,
}

struct AtomSinkState {
    id: felt,
    index: Grid,
}

func update_atoms_moved{syscall_ptr: felt*, range_check_ptr}(
    mech_id: felt, pos: Grid, i: felt, atoms_len: felt, atoms: AtomState*
) -> (is_moved: felt, atoms_new: AtomState*) {
    alloc_locals;
    if (atoms_len == i) {
        return (0, atoms);
    }
    tempvar atom = [atoms + i * ns_atoms.ATOM_STATE_SIZE];
    if (atom.status == ns_atoms.FREE) {
        return update_atoms_moved(mech_id, pos, i + 1, atoms_len, atoms);
    }
    if (atom.possessed_by == mech_id) {
        // TODO make a generic copy functin which takes i, atoms and AtomState and returns atoms_new
        let (atoms_new: AtomState*) = alloc();
        tempvar len_1 = i * ns_atoms.ATOM_STATE_SIZE;
        tempvar len_2 = (atoms_len - i - 1) * ns_atoms.ATOM_STATE_SIZE;
        memcpy(atoms_new, atoms, len_1);
        assert [atoms_new + len_1] = AtomState(atom.id, atom.type, atom.status, pos, mech_id);
        memcpy(
            atoms_new + len_1 + ns_atoms.ATOM_STATE_SIZE,
            atoms + len_1 + ns_atoms.ATOM_STATE_SIZE,
            len_2,
        );
        return (1, atoms_new);
    }
    return update_atoms_moved(mech_id, pos, i + 1, atoms_len, atoms);
}

func update_atoms_status{syscall_ptr: felt*, range_check_ptr}(
    mech_id: felt, pos: Grid, i: felt, atoms_len: felt, atoms: AtomState*, status: felt
) -> (atoms_new: AtomState*) {
    alloc_locals;
    if (atoms_len == i) {
        return (atoms_new=atoms);
    }
    tempvar atom = [atoms + i * ns_atoms.ATOM_STATE_SIZE];
    if (atom.status == ns_atoms.FREE and pos.x == atom.index.x and pos.y == atom.index.y) {
        let (atoms_new: AtomState*) = alloc();
        tempvar len_1 = i * ns_atoms.ATOM_STATE_SIZE;
        tempvar len_2 = (atoms_len - i - 1) * ns_atoms.ATOM_STATE_SIZE;
        memcpy(atoms_new, atoms, len_1);
        assert [atoms_new + len_1] = AtomState(atom.id, atom.type, status, pos, mech_id);
        memcpy(
            atoms_new + len_1 + ns_atoms.ATOM_STATE_SIZE,
            atoms + len_1 + ns_atoms.ATOM_STATE_SIZE,
            len_2,
        );
        return (atoms_new=atoms_new);
    }
    return update_atoms_status(mech_id, pos, i + 1, atoms_len, atoms, status);
}

func populate_faucets{range_check_ptr}(
    faucets_len: felt, faucets: AtomFaucetState*, atoms_len: felt, atoms: AtomState*
) -> felt {
    alloc_locals;
    if (faucets_len == 0) {
        return atoms_len;
    }
    tempvar faucet = [faucets];
    let is_free = check_faucet_free(faucet.index, atoms_len, atoms);
    if (is_free == 1) {
        assert [atoms + atoms_len * ns_atoms.ATOM_STATE_SIZE] = AtomState(atoms_len, faucet.type, ns_atoms.FREE, Grid(faucet.index.x, faucet.index.y), 0);
        return populate_faucets(
            faucets_len - 1, faucets + ns_atom_faucets.ATOM_FAUCET_SIZE, atoms_len + 1, atoms
        );
    }
    return populate_faucets(
        faucets_len - 1, faucets + ns_atom_faucets.ATOM_FAUCET_SIZE, atoms_len, atoms
    );
}

func check_faucet_free{range_check_ptr}(pos: Grid, atoms_len: felt, atoms: AtomState*) -> felt {
    if (atoms_len == 0) {
        return 1;
    }
    tempvar atom = [atoms];
    if (pos.x == atom.index.x and pos.y == atom.index.y and atom.status == ns_atoms.FREE) {
        return 0;
    }
    return check_faucet_free(pos, atoms_len - 1, atoms + ns_atoms.ATOM_STATE_SIZE);
}