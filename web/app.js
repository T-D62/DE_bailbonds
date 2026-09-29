const app = document.getElementById('app');
const bondList = document.getElementById('bond-list');
const statusText = document.getElementById('status');
const confirmLayer = document.getElementById('confirm');
const accountName = document.getElementById('account-name');
let bonds = [];
let currentView = 'unpaid';
let pendingBond = null;
let paymentPending = false;

function nuiPost(action, data = {}) {
    return fetch(`https://${GetParentResourceName()}/${action}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data),
    }).then(response => response.json()).catch(() => ({ ok: false }));
}

function formatMoney(value) {
    return `$${(Number(value) || 0).toLocaleString('en-US')}`;
}

function render() {
    const unpaid = bonds.filter(bond => Number(bond.paid) !== 1);
    const total = unpaid.reduce((sum, bond) => sum + (Number(bond.price) || 0), 0);
    document.getElementById('outstanding-total').textContent = formatMoney(total);
    document.getElementById('outstanding-count').textContent = unpaid.length;
    accountName.textContent = window.payAccount || 'bank';
    bondList.replaceChildren();

    const filtered = bonds.filter(bond => currentView === 'paid'
        ? Number(bond.paid) === 1
        : Number(bond.paid) !== 1);

    if (filtered.length === 0) {
        const empty = document.createElement('div');
        empty.className = 'empty';
        empty.textContent = currentView === 'paid'
            ? 'No paid bonds to display.'
            : 'There are no outstanding bonds to pay.';
        bondList.append(empty);
        return;
    }

    filtered.forEach(bond => {
        const row = document.createElement('article');
        row.className = 'bond';
        const heading = document.createElement('div');
        heading.className = 'bond-heading';
        const name = document.createElement('h2');
        name.className = 'bond-name';
        name.textContent = bond.name || 'Bond';
        const amount = document.createElement('span');
        amount.className = 'bond-amount';
        amount.textContent = formatMoney(bond.price);
        heading.append(name, amount);
        row.append(heading);

        const meta = document.createElement('div');
        meta.className = 'bond-meta';
        meta.textContent = currentView === 'paid'
            ? `Paid${bond.paid_at ? ` · ${bond.paid_at}` : ''}`
            : `Created${bond.created_at ? ` · ${bond.created_at}` : ''}`;
        row.append(meta);

        if (currentView === 'unpaid') {
            const pay = document.createElement('button');
            pay.className = 'button primary';
            pay.type = 'button';
            pay.textContent = 'Pay this bond';
            pay.disabled = paymentPending;
            pay.addEventListener('click', () => openConfirmation(bond));
            row.append(pay);
        }
        bondList.append(row);
    });
}

function openConfirmation(bond) {
    pendingBond = bond;
    document.getElementById('confirm-copy').textContent =
        `Pay ${formatMoney(bond.price)} for ${bond.name || 'this bond'} from your ${window.payAccount || 'bank'} account?`;
    confirmLayer.hidden = false;
    document.getElementById('confirm-payment').focus();
}

function closeConfirmation() {
    confirmLayer.hidden = true;
    pendingBond = null;
}

document.getElementById('close').addEventListener('click', () => nuiPost('close'));
document.getElementById('cancel-payment').addEventListener('click', closeConfirmation);
document.getElementById('confirm-payment').addEventListener('click', async event => {
    if (!pendingBond || paymentPending) return;
    const button = event.currentTarget;
    paymentPending = true;
    button.disabled = true;
    statusText.textContent = 'Submitting payment…';
    render();
    const result = await nuiPost('payBond', { id: pendingBond.id });
    if (!result.ok) {
        paymentPending = false;
        statusText.textContent = 'Payment could not be submitted. Please try again.';
        closeConfirmation();
        render();
    } else {
        statusText.textContent = 'Waiting for payment confirmation…';
        closeConfirmation();
    }
});

document.querySelectorAll('.tab').forEach(button => {
    button.addEventListener('click', () => {
        currentView = button.dataset.view;
        document.querySelectorAll('.tab').forEach(tab => tab.classList.toggle('active', tab === button));
        statusText.textContent = '';
        render();
    });
});

window.addEventListener('message', event => {
    const message = event.data || {};
    if (message.action === 'open') {
        document.body.classList.add('visible');
        app.setAttribute('aria-hidden', 'false');
        statusText.textContent = '';
        currentView = 'unpaid';
        document.querySelectorAll('.tab').forEach(tab => tab.classList.toggle('active', tab.dataset.view === currentView));
    } else if (message.action === 'close') {
        document.body.classList.remove('visible');
        app.setAttribute('aria-hidden', 'true');
        closeConfirmation();
        paymentPending = false;
    } else if (message.action === 'setBonds') {
        bonds = Array.isArray(message.bonds) ? message.bonds : [];
        window.payAccount = message.payAccount || 'bank';
        paymentPending = false;
        render();
    } else if (message.action === 'paymentResult') {
        paymentPending = false;
        const messages = {
            success: 'Payment complete. The bond list has been updated.',
            insufficient: 'You do not have enough money to pay this bond.',
            unavailable: 'This bond is no longer available to pay.',
            failure: 'Payment failed. Please try again later.',
        };
        statusText.textContent = messages[message.result] || '';
        render();
    }
});

document.addEventListener('keydown', event => {
    if (event.key === 'Escape') {
        if (!confirmLayer.hidden) {
            closeConfirmation();
        } else {
            nuiPost('close');
        }
    }
});
