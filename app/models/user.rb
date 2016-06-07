# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'digest/sha1'

class User < ActiveRecord::Base
    validates :email, presence: true

    devise :omniauthable, :omniauth_providers => [:backstage]

    ROLES = define_enum(:role, [:ADMIN, :OPERATOR, :VIEWER])

    # before_save :check_auth_tokens
    # before_save   :ensure_authentication_token
    # after_destroy :persist_audits

    # has_many :audits, :as => :user

    def self.from_omniauth(auth)
      user = User.where(email: auth.info.email).first
      if user.nil? # Doesnt exist yet. Lets create it
        user = User.new({
          active: false,
          uid: auth.uid,
          email: auth.info.email,
          name: auth.info.name,
          password: Devise.friendly_token[0,20],
          oauth_token: auth.credentials.token,
          oauth_expires_at: Time.at(auth.credentials.expires_at)
        })
        user.save!
      else # Already created. lets update it
        user.update_attributes({
          uid: auth.uid,
          email: auth.info.email,
          name: auth.info.name,
          password: Devise.friendly_token[0,20],
          oauth_token: auth.credentials.token,
          oauth_expires_at: Time.at(auth.credentials.expires_at)
        })
      end
      user
    end

    def ensure_authentication_token
      if authentication_token.blank?
        self.authentication_token = generate_authentication_token
      end
    end

    # ROLES = [:ADMIN, :OPERATOR, :VIEWER].inject(Hash.new) do |hash, role|
    #     role_str = role.to_s[0]
    #     const_set(('ROLE_' + role.to_s).to_sym, role_str)
    #     hash[role_str] = role
    #     hash
    # end

    # prevents a user from submitting a crafted form that bypasses activation
    # anything else you want your user to change should be added here.
    attr_accessible :name, :email, :role, :active, :password, :oauth_token, :oauth_expires_at, :uid

    # def admin?
    #     role == ROLE_ADMIN
    # end

    # def operator?
    #     role == ROLE_OPERATOR
    # end

    # def viewer?
    #     role == ROLE_VIEWER
    # end

    def auth_json
        self.to_json(:root => false, :only => [:id, :authentication_token])
    end

    protected

    def persist_audits
        quoted_login = ActiveRecord::Base.connection.quote(self.login)
        Audit.update_all(
            "username = #{quoted_login}",
            [ 'user_type = ? AND user_id = ?', self.class.name, self.id ]
        )
    end

    private
    def generate_authentication_token
    loop do
      token = Devise.friendly_token
      break token unless User.where(authentication_token: token).first
    end
  end
end
