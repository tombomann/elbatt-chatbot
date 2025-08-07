// Enkel embed script uten lengdebegrensninger - v1754536019
console.log('Embed script loaded - v1754536019');

// Fjern eventuell eksisterende widget
const existingWidget = document.getElementById('elbatt-chat-widget');
if (existingWidget) {
    existingWidget.remove();
}

// Fjern eventuell eksisterende knapp
const existingBtn = document.getElementById('elbatt-chat-open-btn');
if (existingBtn) {
    existingBtn.remove();
}

console.log('Embed script initialized');
