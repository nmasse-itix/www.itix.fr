//
// Search engine of the "search" page.
//
// The search index, the taxonomies and the translated strings are generated
// by Hugo in a JSON data block (see layouts/search.html), so that no inline
// script is needed (Content Security Policy).
//
var searchData = JSON.parse(document.getElementById('search-data').textContent);
var taxonomies = searchData.taxonomies;
var searchDb = searchData.index;

var searchResults = document.getElementById('searchResults'); // targets the <div> above
var searchInput = document.getElementById('searchInput'); // input box for search
var lastSearch = "";

// Helper function to create an element with attributes
function tag(name, attrs) {
  var el = document.createElement(name.toString());

  !!attrs && Object.keys(attrs).forEach(function(key) {
    el.setAttribute(key, attrs[key]);
  });

  return el;
}

function printSearchResult(result) {
    var section = tag("section");
    
    //
    // Article headline
    //
    var a = tag("a", { href: result.item.permalink });
    a.textContent = result.item.title;
    if (result.item.hasEnFlag) {
        var uk_flag_svg = document.getElementById("embedded-svg-en");
        if (uk_flag_svg != null) {
            var img = uk_flag_svg.firstChild.cloneNode(true);
            a.appendChild(img);
        }
    }
    var h4 = tag("h4");
    h4.textContent = result.item.type_label + " >> ";
    h4.appendChild(a);
    section.appendChild(h4);

    //
    // Metadata
    //
    if (result.item.type != "page") {
        var div = tag("div", { 'class': 'post-metadata'});
        var span_date = tag("span", { 'class': 'publication-date' });
        span_date.textContent = searchData.i18n.published_on + " " + result.item.date;
        div.appendChild(span_date);
        if (result.item.topics != null) {
            result.item.topics.forEach(function (v) {
                var topic_detail = taxonomies.topics[v];
                if (topic_detail == null) {
                    return;
                }
                var span = tag("span", { 'class': 'topic' });
                var link_svg = document.getElementById("embedded-svg-link");
                if (link_svg != null) {
                    var img = link_svg.firstChild.cloneNode(true);
                    span.appendChild(img);
                }
                var a = tag("a", { href: topic_detail.href });
                a.textContent = topic_detail.title;
                span.appendChild(a);
                div.appendChild(span);
            });
        }
        if (result.item.opensource != null) {
            result.item.opensource.forEach(function (v) {
                var opensource_detail = taxonomies.opensource[v];
                if (opensource_detail == null) {
                    return;
                }
                var span = tag("span", { 'class': 'opensource' });
                var label_svg = document.getElementById("embedded-svg-label");
                if (label_svg != null) {
                    var img = label_svg.firstChild.cloneNode(true);
                    span.appendChild(img);
                }
                var a = tag("a", { href: opensource_detail.href });
                a.textContent = opensource_detail.title;
                span.appendChild(a);
                div.appendChild(span);
            });
        }
        if (result.item.reading_time != null) {
            var span = tag("span", { 'class': 'reading-time' });
            var schedule_svg = document.getElementById("embedded-svg-schedule");
                if (schedule_svg != null) {
                    var img = schedule_svg.firstChild.cloneNode(true);
                    span.appendChild(img);
                }
            var readingTime = document.createTextNode(result.item.reading_time);
            span.appendChild(readingTime);
            div.appendChild(span);
        }
        section.appendChild(div);
    }

    var p = tag("p", {});
    p.textContent = result.item.summary;
    var a = tag("a", { href: result.item.permalink, 'class': 'continue-reading' });
    a.textContent = searchData.i18n.continue_reading;
    p.appendChild(a);
    section.appendChild(p);

    searchResults.appendChild(section);
}

function clearSearchResults() {
  var child = searchResults.lastElementChild;  
  while (child) { 
    searchResults.removeChild(child); 
    child = searchResults.lastElementChild; 
  } 
}

//
// load the search index
//
function fuseInit(searchDb) { 
  var options = { // fuse.js options; check fuse.js website for details
    shouldSort: true,
    ignoreLocation: true,
    threshold: 0.4,
    minMatchCharLength: 3,
    keys: [
        'title',
        'permalink',
        'summary',
        'topics',
        'opensource'
        ]
    };
    fuse = new Fuse(searchDb, options); // build the index from the json file
}

// 
// using the index loaded previously, run  a search query (for "term")
// every time a letter is typed in the search box
//
function executeSearch(term) {
  if (lastSearch == term) {
    // Don't query Fuse if the search terms have not changed
    return;
  }

  clearSearchResults();
  let results = fuse.search(term);
  results.slice(0, 20).forEach(printSearchResult);
  lastSearch = term;
}

// Initialize the Fuse.io framework with the Search DB
fuseInit(searchDb);

//
// execute search as each character is typed
//
searchInput.onkeyup = function(e) { 
  executeSearch(this.value);
}
