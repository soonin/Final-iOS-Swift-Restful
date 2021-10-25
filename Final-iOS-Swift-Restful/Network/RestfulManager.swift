//
//  RestfulManager.swift
//  Final-iOS-Swift-Restful
//
//  Created by Pooya on 2021-10-18.
//  Copyright © 2021 centurytrail.com. All rights reserved.
//

import Foundation

// MARK: RestManager
/// class to perform web requests including :
/// HTTP method
/// Request & Response HTTP headers
/// URL query parameters
/// HTTP body
class RestManager {
    
    // MARK: - Properties
    
    var requestHttpHeaders = RestEntity()
    
    var urlQueryParameters = RestEntity()
    
    var httpBodyParameters = RestEntity()
    
    var httpBody: Data?
    
    
    // MARK: - Public Methods
    
    /// func to make Request
    ///  - Parameters :
    ///    - url : URL , accepts a URL value
    ///    - httpMethod : HttpMethod,
    ///    - completion :
    ///
    ///  - Returns : Void
    func makeRequest(toURL url: URL,
                     withHttpMethod httpMethod: HttpMethod,
                     completion: @escaping (_ result: Results) -> Void) {
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let targetURL = self?.addURLQueryParameters(toURL: url)
            let httpBody = self?.getHttpBody()
            
            guard let request = self?.prepareRequest(withURL: targetURL, httpBody: httpBody, httpMethod: httpMethod) else
            {
                completion(Results(withError: CustomError.failedToCreateRequest))
                print("prepare error")
                return
            }
            
            let sessionConfiguration = URLSessionConfiguration.default
            let session = URLSession(configuration: sessionConfiguration)
            let task = session.dataTask(with: request) { (data, response, error) in
                completion(Results(withData: data,
                                   response: Response(fromURLResponse: response),
                                   error: error))
            }
            task.resume()
        }
    }
    
    
    /// func to get Data
    ///  - Parameters :
    ///    - url : URL , accepts a URL value
    ///    - completion :
    ///
    ///  - Returns : Void
    func getData(fromURL url: URL, completion: @escaping (_ data: Data?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let sessionConfiguration = URLSessionConfiguration.default
            let session = URLSession(configuration: sessionConfiguration)
            let task = session.dataTask(with: url, completionHandler: { (data, response, error) in
                guard let data = data else { completion(nil); return }
                completion(data)
            })
            task.resume()
        }
    }
    
    
    
    // MARK: - Private Methods
    
    /// func to aapending Parameters To URL
    ///  - Parameters :
    ///    - url : URL , accepts a URL value
    ///
    ///   make sure that there are URL query parameters to append to the query.
    ///   If not, we just return the input URL
    ///  - Returns : URL , returns a URL value with added queryItems
    private func addURLQueryParameters(toURL url: URL) -> URL {
        if urlQueryParameters.totalItems() > 0 {
            guard var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return url }
            var queryItems = [URLQueryItem]()
            for (key, value) in urlQueryParameters.allValues() {
                let item = URLQueryItem(name: key, value: value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed))
                
                queryItems.append(item)
            }
            
            urlComponents.queryItems = queryItems
            
            guard let updatedURL = urlComponents.url else { return url }
            return updatedURL
        }
        
        return url
    }
    
    
    /// func to get Http Body
    ///  - Parameters :
    ///    - nothing
    ///
    ///  - Returns : Data? , returns a Data?
    private func getHttpBody() -> Data? {
        guard let contentType = requestHttpHeaders.value(forKey: "Content-Type") else { return nil }
        
        if contentType.contains("application/json") {
            return try? JSONSerialization.data(withJSONObject: httpBodyParameters.allValues(), options: [.prettyPrinted, .sortedKeys])
        } else if contentType.contains("application/x-www-form-urlencoded") {
            let bodyString = httpBodyParameters.allValues().map { "\($0)=\(String(describing: $1.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)))" }.joined(separator: "&")
            return bodyString.data(using: .utf8)
        } else {
            return httpBody
        }
    }
    
    
    /// func to prepare Request
    ///  - Parameters :
    ///    - url : URL , accepts a URL value
    ///    - httpBody : Data? ,
    ///    - httpMethod: HttpMethod ,
    ///
    ///   make sure that there are URL query parameters to append to the query.
    ///   If not, we just return the input URL
    ///  - Returns : URLRequest? , returns a URLRequest?
    private func prepareRequest(withURL url: URL?, httpBody: Data?, httpMethod: HttpMethod) -> URLRequest? {
        guard let url = url else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = httpMethod.rawValue
        
        for (header, value) in requestHttpHeaders.allValues() {
            request.setValue(value, forHTTPHeaderField: header)
        }
        
        request.httpBody = httpBody
        return request
    }
}


// MARK: - RestManager Custom Types
extension RestManager {
    
    /// enumeration that will represent the various HTTP methods
    enum HttpMethod: String {
        case get
        case post
        case put
        case patch
        case delete
    }
    
    
    /// struct to represent
    /// HTTP Headers & URL & HTTP Body Parameters
    struct RestEntity {
        private var values: [String: String] = [:]
        
        mutating func add(value: String, forKey key: String) {
            values[key] = value
        }
        
        func value(forKey key: String) -> String? {
            return values[key]
        }
        
        func allValues() -> [String: String] {
            return values
        }
        
        func totalItems() -> Int {
            return values.count
        }
    }
    
    
    /// struct to representing The Response
    ///  - A response may include the following three different kind of data:
    ///    - A numeric status (HTTP status code) indicating the outcome of the request. This is always returned by the server.
    ///    - HTTP headers. They can optionally exist in the response.
    ///    - Response body, which is the actual data a server sends back to the client app.
    struct Response {
        /// We will keep the actual response object (URLResponse) in it. Note that this object does not contain the actual data returned from server.
        var response: URLResponse?
        /// The status code (2xx, 3xx, etc) that represents the outcome of the request.
        var httpStatusCode: Int = 0
        /// An instance of the RestEntity struct that we implemented and discussed about in the previous part.
        var headers = RestEntity()
        
        /// initialize a Response object
        init(fromURLResponse response: URLResponse?) {
            guard let response = response else { return }
            self.response = response
            httpStatusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            
            if let headerFields = (response as? HTTPURLResponse)?.allHeaderFields {
                for (key, value) in headerFields {
                    headers.add(value: "\(value)", forKey: "\(key)")
                }
            }
        }
    }
    
    
    /// struct to representing The Response
    ///  - A results may include the following different kind of data:
    ///    - Actual data coming from the server if the request was successful.
    ///    - Other data in the response (see previous part).
    ///    - Any potential errors.
    /// Note that all properties are marked as optionals.
    struct Results {
        // Data returned on successful requests is usually a JSON object which should be decoded properly by classes which will use the RestManager class.
        var data: Data?
        /// struct to managing The Response
        var response: Response?
        /// representing an error value that can be thrown.
        var error: Error?
        
        /// initialize a Results object withData
        init(withData data: Data?, response: Response?, error: Error?) {
            self.data = data
            self.response = response
            self.error = error
        }
        
        /// initialize a Results object withError
        init(withError error: Error) {
            self.error = error
        }
    }
    
    /// enumeration that will represent the CustomError
    /// Conforms to the Error protocol
    /// makes it mandatory to extend the CustomError enum in order to provide
    /// a localized description
    enum CustomError: Error {
        case failedToCreateRequest
    }
}


// MARK: - Custom Error Description
extension RestManager.CustomError: LocalizedError {
    public var localizedDescription: String {
        switch self {
        case .failedToCreateRequest: return NSLocalizedString("Unable to create the URLRequest object", comment: "")
        }
    }
}


