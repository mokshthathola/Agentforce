import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';
import generateSummary from '@salesforce/apex/CaseSummaryController.generateSummary';
import saveSummary from '@salesforce/apex/CaseSummaryController.saveSummary';

export default class CaseAiSummary extends LightningElement {
    @api recordId;

    draft;
    isLoading = false;
    error;

    get hasDraft() {
        return this.draft !== undefined && this.draft !== null;
    }

    get showEmptyState() {
        return !this.hasDraft && !this.isLoading && !this.error;
    }

    get generateLabel() {
        return this.hasDraft ? 'Regenerate' : 'Generate Summary';
    }

    get isUseDisabled() {
        return this.isLoading || !this.draft || !this.draft.trim();
    }

    async handleGenerate() {
        this.isLoading = true;
        this.error = undefined;
        try {
            this.draft = await generateSummary({ caseId: this.recordId });
        } catch (e) {
            this.error = this.reduceError(e);
        } finally {
            this.isLoading = false;
        }
    }

    handleChange(event) {
        this.draft = event.target.value;
    }

    handleDiscard() {
        this.draft = undefined;
        this.error = undefined;
    }

    async handleUse() {
        this.isLoading = true;
        this.error = undefined;
        try {
            await saveSummary({ caseId: this.recordId, summary: this.draft });
            // Refresh the record page so the Case Summary field shows the new value
            await notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Summary saved',
                    message: 'The AI summary was added to Case Summary.',
                    variant: 'success'
                })
            );
            this.draft = undefined;
        } catch (e) {
            this.error = this.reduceError(e);
        } finally {
            this.isLoading = false;
        }
    }

    reduceError(e) {
        return e?.body?.message || e?.message || 'Something went wrong. Please try again.';
    }
}