name: Check Workflow Status

on:
  workflow_run:
    workflows: ["Deploy Backend & Frontend with Rollback and Notifications"]
    types:
      - completed

jobs:
  check_status:
    runs-on: ubuntu-latest
    steps:
      - name: Hent siste workflow run
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          REPO: tombomann/elbatt-chatbot
        run: |
          LATEST_RUN=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
            "https://api.github.com/repos/$REPO/actions/runs?per_page=1" | jq -r '.workflow_runs[0]')
          STATUS=$(echo "$LATEST_RUN" | jq -r '.status')
          CONCLUSION=$(echo "$LATEST_RUN" | jq -r '.conclusion')
          HTML_URL=$(echo "$LATEST_RUN" | jq -r '.html_url')

          echo "Workflow Status: $STATUS"
          echo "Workflow Conclusion: $CONCLUSION"
          echo "Detaljer: $HTML_URL"

          if [[ "$STATUS" != "completed" ]]; then
            echo "Workflow kjører fortsatt..."
            exit 0
          fi

          if [[ "$CONCLUSION" != "success" ]]; then
            echo "Workflow feilet - vurder rollback eller varsling"
            # Her kan du f.eks. sende Slack-varsling, epost eller kjøre rollback-script
            exit 1
          else
            echo "Workflow fullført OK!"
          fi
