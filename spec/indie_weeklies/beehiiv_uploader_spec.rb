# frozen_string_literal: true

require "spec_helper"
require "fileutils"

RSpec.describe IndieWeeklies::BeehiivUploader do
  let(:uploader) { described_class.new }
  let(:newsletter_data) do
    {
      title: "Indie Weeklies – Edition 42",
      tagline: "The one where something amazing happened",
      content: "<html><body>Newsletter content</body></html>",
      file_path: "/tmp/indie-weeklies-2023-W42.html"
    }
  end
  
  # Clean up the last edition file after tests
  after do
    if File.exist?(described_class::LAST_EDITION_FILE)
      FileUtils.rm(described_class::LAST_EDITION_FILE)
    end
  end
  
  describe "#upload" do
    it "uploads the newsletter to Beehiiv" do
      # Mock the API call
      expect(uploader).to receive(:post_with_retries).with(
        "posts",
        hash_including(
          publication_id: ENV["BEEHIIV_PUBLICATION_ID"],
          title: "Indie Weeklies – Edition 42",
          subtitle: "The one where something amazing happened",
          content: "<html><body>Newsletter content</body></html>",
          status: "draft"
        )
      ).and_return({
        "data" => {
          "id" => "post123"
        }
      })
      
      result = uploader.upload(newsletter_data)
      
      expect(result).to include(
        post_id: "post123",
        preview_url: "https://app.beehiiv.com/posts/post123"
      )
    end
    
    it "returns nil if the API call fails" do
      expect(uploader).to receive(:post_with_retries).and_return(nil)
      
      result = uploader.upload(newsletter_data)
      
      expect(result).to be_nil
    end
    
    it "skips upload if the edition has already been published" do
      # Create a last_edition.yml file with the current edition
      FileUtils.mkdir_p(File.dirname(described_class::LAST_EDITION_FILE))
      File.write(
        described_class::LAST_EDITION_FILE,
        { "editions" => ["#{Date.today.year}-W#{Date.today.cweek}"] }.to_yaml
      )
      
      # The API should not be called
      expect(uploader).not_to receive(:post_with_retries)
      
      result = uploader.upload(newsletter_data)
      
      expect(result).to be_nil
    end
  end
  
  describe "#already_published?" do
    it "returns true if the edition is in the list" do
      FileUtils.mkdir_p(File.dirname(described_class::LAST_EDITION_FILE))
      File.write(
        described_class::LAST_EDITION_FILE,
        { "editions" => ["2023-W42"] }.to_yaml
      )
      
      result = uploader.send(:already_published?, "2023-W42")
      
      expect(result).to be true
    end
    
    it "returns false if the edition is not in the list" do
      FileUtils.mkdir_p(File.dirname(described_class::LAST_EDITION_FILE))
      File.write(
        described_class::LAST_EDITION_FILE,
        { "editions" => ["2023-W41"] }.to_yaml
      )
      
      result = uploader.send(:already_published?, "2023-W42")
      
      expect(result).to be false
    end
    
    it "returns false if the file doesn't exist" do
      if File.exist?(described_class::LAST_EDITION_FILE)
        FileUtils.rm(described_class::LAST_EDITION_FILE)
      end
      
      result = uploader.send(:already_published?, "2023-W42")
      
      expect(result).to be false
    end
  end
  
  describe "#mark_as_published" do
    it "adds the edition to the list" do
      uploader.send(:mark_as_published, "2023-W42")
      
      data = YAML.load_file(described_class::LAST_EDITION_FILE)
      expect(data["editions"]).to include("2023-W42")
    end
    
    it "creates the file if it doesn't exist" do
      if File.exist?(described_class::LAST_EDITION_FILE)
        FileUtils.rm(described_class::LAST_EDITION_FILE)
      end
      
      uploader.send(:mark_as_published, "2023-W42")
      
      expect(File.exist?(described_class::LAST_EDITION_FILE)).to be true
      data = YAML.load_file(described_class::LAST_EDITION_FILE)
      expect(data["editions"]).to include("2023-W42")
    end
  end
end