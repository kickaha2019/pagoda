require "selenium-webdriver"

driver = Selenium::WebDriver.for :firefox

# GOG
driver.navigate.to "http://www.gog.com/games/adventure##sort=bestselling&page=1"
#driver.find_element( :link_text, "Browse Games").click
#driver.find_element( :link_text, "Adventure").click

#puts driver.execute_script( "return currentPage")
#puts driver.execute_script( "return totalPages")

#driver.execute_script( "nextPage()")



html = []

10.times do
	universes = driver.find_elements( :class, "universe")
	html << driver.execute_script( "return arguments[0].innerHTML", universes[-1])
	#html << driver.execute_script( "return document.getElementsByClassName('universe').innerHTML")
	nexts = driver.find_elements( :class, "pagin__next")
	break if nexts[-1].attribute( 'class') != 'pagin__next'
	#driver.execute_script( "arguments[0].scrollIntoView(true);", nexts[-1])
	driver.execute_script( "window.scrollTo(0,document.body.scrollHeight);")
	sleep 1
	nexts[-1].click
	sleep 15
end

File.open( ARGV[0] + "/gog.html", "w") do |f|
	f.puts "<html><body>" + html.join('') + "</body></html>"
end

driver.quit
