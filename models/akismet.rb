class Akismet
    def validateKey(apikey, siteurl)
        result = Net::HTTP.post_form(URI.parse('http://rest.akismet.com/1.1/verify-key'), {:key => apikey, :blog => siteurl})
        return result.body == 'valid'
    end
end