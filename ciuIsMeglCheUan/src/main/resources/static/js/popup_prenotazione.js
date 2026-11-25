// Attacco event listener a tutti i bottoni dopo il render
document.addEventListener("DOMContentLoaded", function() {
    document.querySelectorAll('.btn-seleziona').forEach(btn => {
        btn.addEventListener('click', function() {
            const targa = this.getAttribute('data-targa');
            const dataRitiro = this.getAttribute('data-ritiro');
            const dataConsegna = this.getAttribute('data-consegna');
            showOpzioniPrenotazionePopup(targa, dataRitiro, dataConsegna);
        });
    });

    const modal = document.getElementById('opzioniPrenotazioneModal');
    if (modal) {
        modal.addEventListener('click', function(e) {
            // Chiude se si clicca sul bottone di chiusura (anche caricato via AJAX) o sullo sfondo del modal
            if (e.target.closest('.close-btn') || e.target === modal) {
                closeOpzioniPrenotazionePopup();
            }
        });
    }
});

function showOpzioniPrenotazionePopup(targa, dataRitiro, dataConsegna) {
    // Mostra il modal
    document.getElementById('opzioniPrenotazioneModal').style.display = 'block';
    document.getElementById('opzioniPrenotazioneLoading').style.display = 'block';
    document.getElementById('opzioniPrenotazioneInner').innerHTML = '';

    // AJAX per caricare il fragment Thymeleaf
    fetch('/opzioniPrenotazione?targa=' + encodeURIComponent(targa) +
        '&dataRitiro=' + encodeURIComponent(dataRitiro) +
        '&dataConsegna=' + encodeURIComponent(dataConsegna))
        .then(response => response.text())
        .then(html => {
            document.getElementById('opzioniPrenotazioneInner').innerHTML = html;
            document.getElementById('opzioniPrenotazioneLoading').style.display = 'none';
        })
        .catch(() => {
            document.getElementById('opzioniPrenotazioneInner').innerHTML = '<div style="color:red;">Errore durante il caricamento delle opzioni.</div>';
            document.getElementById('opzioniPrenotazioneLoading').style.display = 'none';
        });
}

function closeOpzioniPrenotazionePopup() {
    document.getElementById('opzioniPrenotazioneModal').style.display = 'none';
}