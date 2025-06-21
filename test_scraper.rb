require 'nokogiri'

# Path to the following.html file
following_html_path = File.expand_path("db/following.html", Dir.pwd)

# Read the HTML file
html = File.read(following_html_path)
doc = Nokogiri::HTML(html)

# Extract Twitter handles from the HTML table
usernames = []

# Find all table rows except the header row
doc.css('table tr').each_with_index do |row, index|
  # Skip the header row
  next if index == 0
  
  # Get the handle from the second column
  handle_cell = row.css('td')[1]
  next unless handle_cell
  
  handle = handle_cell.text.strip
  
  # Extract username by removing the @ prefix
  if handle.start_with?('@')
    username = handle[1..-1] # Remove the @ prefix
    usernames << username unless username.empty?
  end
end

# Print the first 10 usernames
puts "First 10 usernames:"
usernames.take(10).each do |username|
  puts "- #{username}"
end

puts "\nTotal usernames found: #{usernames.size}"