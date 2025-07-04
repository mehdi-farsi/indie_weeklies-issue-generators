# frozen_string_literal: true

require "csv"

module IndieWeeklies
  class AccountPopularity
    ACCOUNTS_CSV_PATH = File.expand_path("../../db/indie_accounts.csv", __dir__)
    
    def initialize
      @popularity_scores = {}
      load_popularity_scores
    end
    
    # Get popularity score for a username
    def get_score(username)
      @popularity_scores[username] || 0
    end
    
    private
    
    # Load popularity scores from CSV file
    def load_popularity_scores
      return unless File.exist?(ACCOUNTS_CSV_PATH)
      
      CSV.foreach(ACCOUNTS_CSV_PATH, headers: true) do |row|
        username = row["username"]
        score = row["popularity_score"].to_i
        @popularity_scores[username] = score
      end
    end
  end
end